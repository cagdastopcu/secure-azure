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

// Useful post-deploy outputs.
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
output containerAppsEnvironmentName string = acaStamp.outputs.containerAppsEnvironmentName
output webContainerAppFqdn string = acaStamp.outputs.webContainerAppFqdn
