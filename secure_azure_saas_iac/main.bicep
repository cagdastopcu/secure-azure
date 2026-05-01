// -----------------------------------------------------------------------------
// TERM GLOSSARY (this file)
// - ARM: Azure Resource Manager control plane that applies deployments.
// - Bicep: Declarative language compiled to ARM templates.
// - Resource Group (RG): Logical container for Azure resources.
// - Parameter: Runtime input value passed into template/module.
// - Module: Reusable Bicep file invoked from another template.
// - Output: Exported value from a template/module.
// - RBAC: Role-Based Access Control authorization model.
// - Managed Identity: Azure-managed service identity without embedded secrets.
// - Private Endpoint: Private IP path to an Azure PaaS service.
// - Private DNS Zone: DNS mapping so service names resolve to private IPs.
// -----------------------------------------------------------------------------// Extra terms used in this root file:
// - CIDR: Network range notation like 10.40.0.0/16.
// - Ingress: Incoming traffic path to an application endpoint.
// - Environment: Deployment stage such as dev/test/prod.
// Root orchestrator template.
// and an application stamp module (ACA + Key Vault + identities + apps).
// Why this file exists:
// - Gives one deployment entrypoint for repeatability and CI/CD simplicity.
// - Centralizes secure defaults so every environment starts from same baseline.
// What: sets deployment scope. Why: controls where ARM can deploy this file.
// Sets where this template is allowed to deploy (resource group scope here).
targetScope = 'resourceGroup'

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Primary deployment location for regional resources.')
// Uses RG location by default to reduce accidental cross-region drift.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param location string = resourceGroup().location

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Environment name.')
// What: allowed-values guard. Why: blocks invalid input values.
// Limits the next input to safe allowed values only.
@allowed([
  // Allowed values intentionally limited to standard SDLC lifecycle tiers.
  'dev'
  'test'
  'prod'
])
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param environment string = 'dev'

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Project prefix for naming.')
// Prefix appears in resource names to support ownership discovery and cost allocation.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param projectPrefix string = 'saas'

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Virtual network address space.')
// Parent CIDR for all workload subnets in this deployment.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param vnetAddressPrefix string = '10.40.0.0/16'

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Subnet for Container Apps infrastructure.')
// /23 (or larger) recommended for ACA environment infrastructure growth.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param acaInfraSubnetPrefix string = '10.40.0.0/23'

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Subnet for private endpoints.')
// Dedicated PE subnet keeps private service interfaces isolated.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param privateEndpointSubnetPrefix string = '10.40.2.0/24'

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Log Analytics retention in days.')
// Keep default retention moderate; raise for compliance/audit requirements.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param logRetentionInDays int = 30

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Container app image to deploy as bootstrap app.')
// Sample image only; replace with enterprise-controlled image registry for production.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param bootstrapContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Allowed CIDR ranges for public web app ingress. Use narrow corporate ranges in production.')
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param allowedIngressCidrs array = [
  // Security default: do not expose to all internet by default.
  // Provide explicit trusted CIDRs when enablePublicWebIngress is true.
  '10.0.0.0/8'
// What: end of the list started above.
// Ends the list started above.
]

// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('If true, web app is internet-facing. If false, web app is internal-only inside ACA environment.')
// Security default: internal-only. Public exposure must be explicit.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param enablePublicWebIngress bool = false

// What: declares helper value. Why: reuse computed values and keep names consistent.
// Creates a helper value used later to avoid repeating long expressions.
var tags = {
  // Shared governance tags propagated to all resources.
  environment: environment
  project: projectPrefix
  managedBy: 'bicep'
  workload: 'saas-platform'
// What: close current settings block.
// Ends the current object block.
}

// Monitoring first so workspace outputs can be consumed by the ACA stamp.
// Why first: apps/environments need logging destination info during creation.
// What: calls child module. Why: split infrastructure into reusable parts.
// Calls another Bicep file so this deployment stays modular and reusable.
module monitoring './platform/monitoring/main.bicep' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: 'monitoring-${projectPrefix}-${environment}'
  // What: starts module input mapping. Why: passes values into child module.
  // Starts the list of inputs sent to the called module.
  params: {
    // What: sets Azure region/location metadata. Why: controls region placement.
    // Sets the Azure region for this resource/assignment metadata.
    location: location
    projectPrefix: projectPrefix
    environment: environment
    retentionInDays: logRetentionInDays
    // What: starts tags block. Why: ownership, cost, and governance metadata.
    // Starts tags used for ownership, cost, and governance filtering.
    tags: tags
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Network baseline before workload deployment; provides subnet IDs.
// Why second: workload stamp references subnet resource IDs for network binding.
// What: calls child module. Why: split infrastructure into reusable parts.
// Calls another Bicep file so this deployment stays modular and reusable.
module network './platform/network/main.bicep' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: 'network-${projectPrefix}-${environment}'
  // What: starts module input mapping. Why: passes values into child module.
  // Starts the list of inputs sent to the called module.
  params: {
    // What: sets Azure region/location metadata. Why: controls region placement.
    // Sets the Azure region for this resource/assignment metadata.
    location: location
    projectPrefix: projectPrefix
    environment: environment
    vnetAddressPrefix: vnetAddressPrefix
    acaInfraSubnetPrefix: acaInfraSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    // What: starts tags block. Why: ownership, cost, and governance metadata.
    // Starts tags used for ownership, cost, and governance filtering.
    tags: tags
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}


// Policy baseline for regional restrictions and mandatory tags.
// Why now: governance is established before workload expansion/drift.
// What: calls child module. Why: split infrastructure into reusable parts.
// Calls another Bicep file so this deployment stays modular and reusable.
module securityBaseline './platform/policy/security-baseline.bicep' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: 'policy-${projectPrefix}-${environment}'
  // What: starts module input mapping. Why: passes values into child module.
  // Starts the list of inputs sent to the called module.
  params: {
    // What: sets Azure region/location metadata. Why: controls region placement.
    // Sets the Azure region for this resource/assignment metadata.
    location: location
    allowedLocations: [
      location
    // What: end of the list started above.
    // Ends the list started above.
    ]
    environmentTagValue: environment
    projectTagValue: projectPrefix
    managedByTagValue: 'bicep'
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}
// Application stamp; depends on monitoring/network outputs for secure wiring.
// What: calls child module. Why: split infrastructure into reusable parts.
// Calls another Bicep file so this deployment stays modular and reusable.
module acaStamp './stamps/aca-stamp/main.bicep' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: 'aca-stamp-${projectPrefix}-${environment}'
  // What: starts module input mapping. Why: passes values into child module.
  // Starts the list of inputs sent to the called module.
  params: {
    // What: sets Azure region/location metadata. Why: controls region placement.
    // Sets the Azure region for this resource/assignment metadata.
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
    // What: starts tags block. Why: ownership, cost, and governance metadata.
    // Starts tags used for ownership, cost, and governance filtering.
    tags: tags
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Useful outputs for operators and pipeline post-deploy steps.
// These are safe metadata outputs (not secrets).
// What: exports value. Why: gives useful post-deploy values to users/other modules.
// Returns a value after deployment for operators or other modules.
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
// What: exports value. Why: gives useful post-deploy values to users/other modules.
// Returns a value after deployment for operators or other modules.
output containerAppsEnvironmentName string = acaStamp.outputs.containerAppsEnvironmentName
// What: exports value. Why: gives useful post-deploy values to users/other modules.
// Returns a value after deployment for operators or other modules.
output webContainerAppFqdn string = acaStamp.outputs.webContainerAppFqdn








