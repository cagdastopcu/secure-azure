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

@description('If true, enable DDoS Network Protection on the VNet.')
param enableDdosProtection bool = false
@description('If true, attach an NSG to private endpoint subnet.')
param enablePrivateEndpointSubnetNsg bool = true

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

@description('If true, deploy private Event Grid topic in data stamp.')
param deployEventGrid bool = false

@description('Event Grid topic name when enabled.')
param eventGridTopicName string = 'app-events-topic'

@description('If true, deploy private Redis in data stamp.')
param deployRedis bool = false

@description('Redis name suffix.')
param redisNameSuffix string = 'cache'

@description('Redis SKU name.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param redisSkuName string = 'Standard'

@description('Redis SKU family.')
param redisSkuFamily string = 'C'

@description('Redis capacity index.')
param redisCapacity int = 1

@description('If true, deploy private Azure SQL in data stamp.')
param deploySql bool = false

@description('SQL server name suffix.')
param sqlServerNameSuffix string = 'sql'

@description('SQL database name.')
param sqlDatabaseName string = 'appdb'

@description('SQL admin login name (used only when deploySql=true).')
param sqlAdminLogin string = 'sqladminuser'

@secure()
@description('SQL admin password (required when deploySql=true).')
param sqlAdminPassword string = ''

@description('If true, enable Defender for Cloud plans at subscription scope.')
param deployDefenderOnboarding bool = true

@description('If true, deploy a subscription monthly budget alert.')
param deployCostBudget bool = false

@description('Monthly budget amount (subscription currency) when cost budget is enabled.')
param monthlyBudgetAmount int = 1000

@description('Budget alert email address when cost budget is enabled.')
param budgetAlertEmail string = 'finops@example.com'

@description('Budget period start date (YYYY-MM-01) used by subscription budget module.')
param budgetStartDate string = '2026-01-01'

@description('If true, deploy Azure Front Door + WAF edge protection.')
param deployEdgeFrontDoor bool = false

@description('If true, apply CanNotDelete locks to critical resources in app/data stamps.')
param applyCriticalResourceDeleteLocks bool = false

@description('If true, enable baseline resource diagnostics to Log Analytics.')
param deployResourceDiagnostics bool = false

@description('If true, deploy baseline platform activity alerts.')
param deployPlatformAlerts bool = false

@description('Email destination for platform activity alerts.')
param platformAlertEmail string = 'ops@example.com'

@description('If true, deploy advanced subscription deny policies for public network access.')
param deployAdvancedPublicNetworkDenyPolicies bool = false

@description('If true, export subscription Activity Log categories to Log Analytics for audit/incident response.')
param deploySubscriptionActivityLogExport bool = true

@description('If true, deploy Azure API Management as secure API gateway control plane.')
param deployApiManagement bool = false

@description('API Management publisher display name.')
param apimPublisherName string = 'SaaS Platform Team'

@description('API Management publisher email.')
param apimPublisherEmail string = 'platform@example.com'

@description('API Management SKU name.')
@allowed([
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param apimSkuName string = 'Developer'

@description('API Management SKU capacity/units.')
param apimSkuCapacity int = 1

@description('If true, enable API Management diagnostic logs to Log Analytics.')
param deployApiManagementDiagnostics bool = true

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
    enableDdosProtection: enableDdosProtection
    enablePrivateEndpointSubnetNsg: enablePrivateEndpointSubnetNsg
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
  params: {}
}

// Optional baseline alert routing for operational/security activity signals.
module platformAlerts './platform/monitoring/alerts.bicep' = if (deployPlatformAlerts) {
  name: 'platform-alerts-${projectPrefix}-${environment}'
  params: {
    location: location
    projectPrefix: projectPrefix
    environment: environment
    alertEmail: platformAlertEmail
    tags: tags
  }
}

// Optional advanced guardrails: deny public network exposure on critical PaaS services.
module advancedPublicNetworkDenyPolicies './platform/policy/public-network-deny.bicep' = if (deployAdvancedPublicNetworkDenyPolicies) {
  name: 'advanced-public-network-deny-${projectPrefix}-${environment}'
  scope: subscription()
  params: {
    enableDeny: true
  }
}

// Optional cost budget guardrail (subscription scope).
module costBudget './platform/governance/cost-budget.bicep' = if (deployCostBudget) {
  name: 'cost-budget-${projectPrefix}-${environment}'
  scope: subscription()
  params: {
    monthlyBudgetAmount: monthlyBudgetAmount
    budgetAlertEmail: budgetAlertEmail
    budgetName: '${projectPrefix}-${environment}-monthly-budget'
    budgetStartDate: budgetStartDate
  }
}

// Optional subscription activity-log export for governance/compliance traceability.
module activityLogExport './platform/governance/activity-log-export.bicep' = if (deploySubscriptionActivityLogExport) {
  name: 'activity-log-export-${projectPrefix}-${environment}'
  scope: subscription()
  params: {
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    enableActivityLogExport: true
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
    deployEventGrid: deployEventGrid
    eventGridTopicName: eventGridTopicName
    deployRedis: deployRedis
    redisNameSuffix: redisNameSuffix
    redisSkuName: redisSkuName
    redisSkuFamily: redisSkuFamily
    redisCapacity: redisCapacity
    deploySql: deploySql
    sqlServerNameSuffix: sqlServerNameSuffix
    sqlDatabaseName: sqlDatabaseName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    applyDeleteLocks: applyCriticalResourceDeleteLocks
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    deployDiagnostics: deployResourceDiagnostics
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
    deployDiagnostics: deployResourceDiagnostics
    infrastructureSubnetResourceId: network.outputs.acaInfraSubnetResourceId
    privateEndpointSubnetResourceId: network.outputs.privateEndpointSubnetResourceId
    containerImage: bootstrapContainerImage
    enablePublicWebIngress: enablePublicWebIngress
    allowedIngressCidrs: allowedIngressCidrs
    applyDeleteLocks: applyCriticalResourceDeleteLocks
    tags: tags
  }
}

// Optional API gateway control plane from blueprint (monetization/governance entry point).
module apiManagement './platform/api/main.bicep' = if (deployApiManagement) {
  name: 'api-management-${projectPrefix}-${environment}'
  params: {
    location: location
    projectPrefix: projectPrefix
    environment: environment
    publisherName: apimPublisherName
    publisherEmail: apimPublisherEmail
    skuName: apimSkuName
    skuCapacity: apimSkuCapacity
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    deployDiagnostics: deployApiManagementDiagnostics
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
output ddosPlanResourceId string = network.outputs.ddosPlanResourceId
output privateEndpointSubnetNsgResourceId string = network.outputs.privateEndpointSubnetNsgResourceId

output storageAccountName string = deployDataStamp ? dataStamp!.outputs.storageAccountName : ''
output serviceBusNamespaceName string = deployDataStamp ? dataStamp!.outputs.serviceBusNamespaceName : ''
output serviceBusQueueName string = deployDataStamp ? dataStamp!.outputs.serviceBusQueueName : ''
output eventGridTopicResourceId string = deployDataStamp ? dataStamp!.outputs.eventGridTopicResourceId : ''
output redisCacheResourceId string = deployDataStamp ? dataStamp!.outputs.redisCacheResourceId : ''
output sqlServerResourceId string = deployDataStamp ? dataStamp!.outputs.sqlServerResourceId : ''
output sqlDatabaseResourceId string = deployDataStamp ? dataStamp!.outputs.sqlDatabaseResourceId : ''
output defenderPlansEnabled array = deployDefenderOnboarding ? defenderOnboarding!.outputs.enabledPlans : []
output platformActionGroupId string = deployPlatformAlerts ? platformAlerts!.outputs.actionGroupId : ''
output advancedPublicNetworkDenyAssignments array = deployAdvancedPublicNetworkDenyPolicies ? advancedPublicNetworkDenyPolicies!.outputs.assignmentNames : []
output activityLogDiagnosticSettingName string = deploySubscriptionActivityLogExport ? activityLogExport!.outputs.activityLogDiagnosticSettingName : ''
output frontDoorEndpointHostName string = deployEdgeFrontDoor && enablePublicWebIngress ? edgeFrontDoor!.outputs.frontDoorEndpointHostName : ''
output apiManagementServiceName string = deployApiManagement ? apiManagement!.outputs.apiManagementServiceName : ''
output apiManagementGatewayUrl string = deployApiManagement ? apiManagement!.outputs.apiManagementGatewayUrl : ''

