// Root orchestrator template.
// This file composes platform baseline modules (monitoring, network, policy)
// and an application stamp module (ACA + Key Vault + identities + apps).
targetScope = 'resourceGroup'

@description('Primary deployment location for regional resources.')
// Uses RG location by default to reduce accidental cross-region drift.
param location string = resourceGroup().location

@description('Environment name.')
@allowed([
  // Allowed values intentionally limited to standard SDLC lifecycle tiers.
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Project prefix for naming.')
// Prefix appears in resource names to support ownership discovery and cost allocation.
param projectPrefix string = 'saas'

@description('Virtual network address space.')
// Parent CIDR for all workload subnets in this deployment.
param vnetAddressPrefix string = '10.40.0.0/16'

@description('Subnet for Container Apps infrastructure.')
// /23 (or larger) recommended for ACA environment infrastructure growth.
param acaInfraSubnetPrefix string = '10.40.0.0/23'

@description('Subnet for private endpoints.')
// Dedicated PE subnet keeps private service interfaces isolated.
param privateEndpointSubnetPrefix string = '10.40.2.0/24'

@description('Log Analytics retention in days.')
// Keep default retention moderate; raise for compliance/audit requirements.
param logRetentionInDays int = 30

@description('Container app image to deploy as bootstrap app.')
// Sample image only; replace with enterprise-controlled image registry for production.
param bootstrapContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Allowed CIDR ranges for public web app ingress. Use narrow corporate ranges in production.')
param allowedIngressCidrs array = [
  // Security default: do not expose to all internet by default.
  // Provide explicit trusted CIDRs when enablePublicWebIngress is true.
  '10.0.0.0/8'
]

@description('If true, web app is internet-facing. If false, web app is internal-only inside ACA environment.')
// Security default: internal-only. Public exposure must be explicit.
param enablePublicWebIngress bool = false

var tags = {
  // Shared governance tags propagated to all resources.
  environment: environment
  project: projectPrefix
  managedBy: 'bicep'
  workload: 'saas-platform'
}

// Monitoring first so workspace outputs can be consumed by the ACA stamp.
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

// Network baseline before workload deployment; provides subnet IDs.
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


// Policy baseline for regional restrictions and mandatory tags.
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
// Application stamp; depends on monitoring/network outputs for secure wiring.
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

// Useful outputs for operators and pipeline post-deploy steps.
// These are safe metadata outputs (not secrets).
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
output containerAppsEnvironmentName string = acaStamp.outputs.containerAppsEnvironmentName
output webContainerAppFqdn string = acaStamp.outputs.webContainerAppFqdn


