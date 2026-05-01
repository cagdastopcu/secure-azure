// Root deployment entrypoint.
// Why: keeps platform + workload deployment as one repeatable command.
targetScope = 'resourceGroup'

@description('Primary Azure region for this deployment.')
param location string = resourceGroup().location

@description('Environment label used in names/tags.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Short project prefix for naming resources.')
param projectPrefix string = 'saas'

@description('VNet CIDR range.')
param vnetAddressPrefix string = '10.40.0.0/16'

@description('Delegated subnet CIDR for ACA environment infrastructure.')
param acaInfraSubnetPrefix string = '10.40.0.0/23'

@description('Subnet CIDR dedicated to private endpoints.')
param privateEndpointSubnetPrefix string = '10.40.2.0/24'

@description('Log retention days in Log Analytics.')
param logRetentionInDays int = 30

@description('Bootstrap container image for sample web/worker apps.')
param bootstrapContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Allowed source CIDRs when public ingress is enabled.')
param allowedIngressCidrs array = [
  '10.0.0.0/8'
]

@description('If true, web app is public; if false, internal-only.')
param enablePublicWebIngress bool = false
@description('If true, deploy secure data/integration stamp (Storage + Service Bus + private endpoints).')
param deployDataStamp bool = true

@description('Storage SKU for data stamp.')
param dataStorageSku string = 'Standard_LRS'

@description('Service Bus SKU for data stamp.')
@allowed([
  'Standard'
  'Premium'
])
param dataServiceBusSku string = 'Standard'

@description('Default queue name in Service Bus namespace.')
param dataQueueName string = 'app-events'

@description('If true, enable Defender for Cloud plans at subscription scope.')
param deployDefenderOnboarding bool = true

@description('If true, deploy a subscription monthly budget alert.')
param deployCostBudget bool = false

@description('Monthly budget amount (subscription currency) when cost budget is enabled.')
param monthlyBudgetAmount int = 1000

@description('Budget alert email address when cost budget is enabled.')
param budgetAlertEmail string = 'finops@example.com'

@description('If true, deploy Azure Front Door + WAF edge protection.')
param deployEdgeFrontDoor bool = false

// Shared governance tags applied across modules.
var tags = {
  environment: environment
  project: projectPrefix
  managedBy: 'bicep'
  workload: 'saas-platform'
}

// Monitoring is deployed first because ACA logs depend on workspace outputs.
module monitoring './platform/monitoring/main.bicep' = {
  name: 'monitoring-${projectPrefix}-${environment}'
  params: {
    location: location
    projectPrefix: projectPrefix
    environment: environment
    retentionInDays: logRetentionInDays
    tags: tags
  }
}

// Network is deployed before workload stamp because stamp needs subnet IDs.
module network './platform/network/main.bicep' = {
  name: 'network-${projectPrefix}-${environment}'
  params: {
    location: location
    projectPrefix: projectPrefix
    environment: environment
    vnetAddressPrefix: vnetAddressPrefix
    acaInfraSubnetPrefix: acaInfraSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    tags: tags
  }
}

// Baseline policy assignment to enforce region/tag governance.
module securityBaseline './platform/policy/security-baseline.bicep' = {
  name: 'policy-${projectPrefix}-${environment}'
  params: {
    location: location
    allowedLocations: [
      location
    ]
    environmentTagValue: environment
    projectTagValue: projectPrefix
    managedByTagValue: 'bicep'
  }
}

// Optional Defender for Cloud onboarding (subscription scope).
module defenderOnboarding './platform/security/defender-onboarding.bicep' = if (deployDefenderOnboarding) {
  name: 'defender-onboarding-${projectPrefix}-${environment}'
  scope: subscription()
  location: location
  params: {}
}

// Optional cost budget guardrail (subscription scope).
module costBudget './platform/governance/cost-budget.bicep' = if (deployCostBudget) {
  name: 'cost-budget-${projectPrefix}-${environment}'
  scope: subscription()
  location: location
  params: {
    monthlyBudgetAmount: monthlyBudgetAmount
    budgetAlertEmail: budgetAlertEmail
    budgetName: '${projectPrefix}-${environment}-monthly-budget'
    budgetStartDate: '${utcNow('yyyy-MM-01')}'
  }
}


// Optional data/integration stamp from blueprint.
module dataStamp './stamps/data-stamp/main.bicep' = if (deployDataStamp) {
  name: 'data-stamp-${projectPrefix}-${environment}'
  params: {
    location: location
    projectPrefix: projectPrefix
    environment: environment
    privateEndpointSubnetResourceId: network.outputs.privateEndpointSubnetResourceId
    storageSku: dataStorageSku
    serviceBusSku: dataServiceBusSku
    defaultQueueName: dataQueueName
    tags: tags
  }
}
// Workload stamp deploys secure runtime components.
module acaStamp './stamps/aca-stamp/main.bicep' = {
  name: 'aca-stamp-${projectPrefix}-${environment}'
  params: {
    location: location
    projectPrefix: projectPrefix
    environment: environment
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    logAnalyticsSharedKey: monitoring.outputs.logAnalyticsPrimarySharedKey
    infrastructureSubnetResourceId: network.outputs.acaInfraSubnetResourceId
    privateEndpointSubnetResourceId: network.outputs.privateEndpointSubnetResourceId
    containerImage: bootstrapContainerImage
    enablePublicWebIngress: enablePublicWebIngress
    allowedIngressCidrs: allowedIngressCidrs
    tags: tags
  }
}

// Optional global edge layer with WAF.
// Safety gate: only deploy when explicitly enabled and app ingress is public.
module edgeFrontDoor './platform/edge/frontdoor.bicep' = if (deployEdgeFrontDoor && enablePublicWebIngress) {
  name: 'edge-frontdoor-${projectPrefix}-${environment}'
  params: {
    location: location
    projectPrefix: projectPrefix
    environment: environment
    originHostName: acaStamp.outputs.webContainerAppFqdn
    tags: tags
  }
}

// Useful post-deploy outputs.
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
output containerAppsEnvironmentName string = acaStamp.outputs.containerAppsEnvironmentName
output webContainerAppFqdn string = acaStamp.outputs.webContainerAppFqdn

output storageAccountName string = deployDataStamp ? dataStamp.outputs.storageAccountName : ''
output serviceBusNamespaceName string = deployDataStamp ? dataStamp.outputs.serviceBusNamespaceName : ''
output serviceBusQueueName string = deployDataStamp ? dataStamp.outputs.serviceBusQueueName : ''
output defenderPlansEnabled array = deployDefenderOnboarding ? defenderOnboarding.outputs.enabledPlans : []
output frontDoorEndpointHostName string = deployEdgeFrontDoor && enablePublicWebIngress ? edgeFrontDoor.outputs.frontDoorEndpointHostName : ''

