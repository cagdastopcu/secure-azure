// -----------------------------------------------------------------------------
// FILE: Root Bicep orchestrator for full SaaS platform deployment.
// USED IN SAAS FLOW: Composes network, monitoring, policy, data, runtime, and optional edge/api modules.
// SECURITY-CRITICAL: Centralizes secure defaults and feature toggles that control public exposure and governance.
// -----------------------------------------------------------------------------
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
@description('If true, deploy Azure Firewall and force ACA subnet outbound traffic through firewall for inspected egress.')
// Security toggle: keeps cost low in dev, but allows strict outbound-control mode when needed.
param enableAzureFirewallForEgress bool = false
@description('CIDR for dedicated Azure Firewall subnet (must be subnet named AzureFirewallSubnet, typically /26 or larger).')
// This range must not overlap other subnets in this VNet.
param azureFirewallSubnetPrefix string = '10.40.3.0/26'
@description('Azure Firewall SKU tier. Premium adds deeper inspection controls; Standard is lower-cost baseline.')
@allowed([
  'Standard'
  'Premium'
])
// Tier influences both feature set and monthly cost profile.
param azureFirewallSkuTier string = 'Standard'
@description('Threat intel mode applied to Azure Firewall policy and instance.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
// Secure default: block known-malicious destinations instead of only logging.
param azureFirewallThreatIntelMode string = 'Deny'

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
// Geo-redundant storage is a resilience-first default for SaaS business continuity.
param dataStorageSku string = 'Standard_GRS'

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
@description('Backup storage redundancy for Azure SQL automated backups. Geo is a strong default for SaaS DR posture.')
@allowed([
  'Local'
  'Zone'
  'Geo'
  'GeoZone'
])
// Geo keeps backup copies in paired region, enabling geo-restore during region failure scenarios.
param sqlBackupStorageRedundancy string = 'Geo'

@description('SQL admin login name (used only when deploySql=true).')
param sqlAdminLogin string = 'sqladminuser'

@secure()
@description('SQL admin password (required when deploySql=true).')
param sqlAdminPassword string = ''
@description('SQL short-term backup retention days for point-in-time recovery (7-35).')
@minValue(7)
@maxValue(35)
// Use upper bound to maximize PITR options after accidental writes/deletes.
param sqlShortTermRetentionDays int = 35
@description('SQL differential backup interval in hours for short-term retention policy.')
@allowed([
  12
  24
])
param sqlDiffBackupIntervalInHours int = 12
@description('If true, enable SQL long-term retention (LTR) backup policy.')
// Keeps older recovery points for compliance and deep-history incident recovery.
param enableSqlLongTermRetention bool = true
@description('SQL weekly LTR retention duration in ISO 8601 (for example P12W).')
// Retain weekly backup snapshots for 12 weeks.
param sqlLongTermWeeklyRetention string = 'P12W'
@description('SQL monthly LTR retention duration in ISO 8601 (for example P12M).')
// Retain monthly backup snapshots for 12 months.
param sqlLongTermMonthlyRetention string = 'P12M'
@description('SQL yearly LTR retention duration in ISO 8601 (for example P5Y).')
// Retain yearly backup snapshots for 5 years.
param sqlLongTermYearlyRetention string = 'P5Y'
@description('ISO week number (1-52) used for yearly LTR snapshot.')
@minValue(1)
@maxValue(52)
// Week 1 means yearly archive snapshot is taken from first ISO week.
param sqlLongTermWeekOfYear int = 1

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
    // Toggle for optional inspected egress pattern.
    enableAzureFirewallForEgress: enableAzureFirewallForEgress
    // Dedicated firewall subnet CIDR passed from root for environment-specific addressing.
    azureFirewallSubnetPrefix: azureFirewallSubnetPrefix
    // Firewall SKU tier controls cost/security feature depth.
    azureFirewallSkuTier: azureFirewallSkuTier
    // Threat intel enforcement mode controls block-vs-alert behavior for known bad indicators.
    azureFirewallThreatIntelMode: azureFirewallThreatIntelMode
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
    // Sets SQL automated backup copy scope for disaster recovery objectives.
    sqlBackupStorageRedundancy: sqlBackupStorageRedundancy
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    // PITR retention window for operational recovery from recent incidents.
    sqlShortTermRetentionDays: sqlShortTermRetentionDays
    // Differential backup cadence to improve restore granularity.
    sqlDiffBackupIntervalInHours: sqlDiffBackupIntervalInHours
    // Enable/disable long-term retention for compliance and deep-history recovery.
    enableSqlLongTermRetention: enableSqlLongTermRetention
    // Weekly LTR window.
    sqlLongTermWeeklyRetention: sqlLongTermWeeklyRetention
    // Monthly LTR window.
    sqlLongTermMonthlyRetention: sqlLongTermMonthlyRetention
    // Yearly LTR window.
    sqlLongTermYearlyRetention: sqlLongTermYearlyRetention
    // Calendar week used for yearly retained snapshot.
    sqlLongTermWeekOfYear: sqlLongTermWeekOfYear
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
// Expose DDoS plan ID for governance checks and incident dashboards.
output ddosPlanResourceId string = network.outputs.ddosPlanResourceId
// Expose NSG ID to verify PE subnet protections in policy/compliance tooling.
output privateEndpointSubnetNsgResourceId string = network.outputs.privateEndpointSubnetNsgResourceId
// Firewall resource ID helps operations target firewall for policy/rule updates.
output azureFirewallResourceId string = network.outputs.azureFirewallResourceId
// Firewall private IP is useful when validating subnet route-table next hop.
output azureFirewallPrivateIp string = network.outputs.azureFirewallPrivateIp
// Firewall policy ID is used by security automation and compliance checks.
output azureFirewallPolicyResourceId string = network.outputs.azureFirewallPolicyResourceId
// Public IP resource ID enables audit of egress identity and IP allowlists.
output azureFirewallPublicIpResourceId string = network.outputs.azureFirewallPublicIpResourceId
// Route-table ID verifies forced-tunneling/egress-control is active.
output acaEgressRouteTableResourceId string = network.outputs.acaEgressRouteTableResourceId

output storageAccountName string = deployDataStamp ? dataStamp!.outputs.storageAccountName : ''
output serviceBusNamespaceName string = deployDataStamp ? dataStamp!.outputs.serviceBusNamespaceName : ''
output serviceBusQueueName string = deployDataStamp ? dataStamp!.outputs.serviceBusQueueName : ''
output eventGridTopicResourceId string = deployDataStamp ? dataStamp!.outputs.eventGridTopicResourceId : ''
output redisCacheResourceId string = deployDataStamp ? dataStamp!.outputs.redisCacheResourceId : ''
output sqlServerResourceId string = deployDataStamp ? dataStamp!.outputs.sqlServerResourceId : ''
output sqlDatabaseResourceId string = deployDataStamp ? dataStamp!.outputs.sqlDatabaseResourceId : ''
// Exposes SQL short-term backup policy resource so audits can verify PITR posture.
output sqlShortTermRetentionPolicyResourceId string = deployDataStamp ? dataStamp!.outputs.sqlShortTermRetentionPolicyResourceId : ''
// Exposes SQL long-term backup policy resource so compliance tooling can verify retention posture.
output sqlLongTermRetentionPolicyResourceId string = deployDataStamp ? dataStamp!.outputs.sqlLongTermRetentionPolicyResourceId : ''
output defenderPlansEnabled array = deployDefenderOnboarding ? defenderOnboarding!.outputs.enabledPlans : []
output platformActionGroupId string = deployPlatformAlerts ? platformAlerts!.outputs.actionGroupId : ''
output advancedPublicNetworkDenyAssignments array = deployAdvancedPublicNetworkDenyPolicies ? advancedPublicNetworkDenyPolicies!.outputs.assignmentNames : []
output activityLogDiagnosticSettingName string = deploySubscriptionActivityLogExport ? activityLogExport!.outputs.activityLogDiagnosticSettingName : ''
output frontDoorEndpointHostName string = deployEdgeFrontDoor && enablePublicWebIngress ? edgeFrontDoor!.outputs.frontDoorEndpointHostName : ''
output apiManagementServiceName string = deployApiManagement ? apiManagement!.outputs.apiManagementServiceName : ''
output apiManagementGatewayUrl string = deployApiManagement ? apiManagement!.outputs.apiManagementGatewayUrl : ''

