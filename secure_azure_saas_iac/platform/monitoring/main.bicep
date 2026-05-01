// -----------------------------------------------------------------------------
// GLOSSARY + SAAS CONTEXT
// - IaC: Infrastructure as Code; cloud resources are defined as versioned text files.
// - Module: Reusable deployment unit with parameters and outputs.
// - Parameter: Input value used to customize deployment per SaaS environment.
// - Resource: Azure object created by this file.
// - Output: Value exported for other modules/tests/pipelines.
// - Least privilege: Grant identities only permissions they strictly need.
// - Private endpoint: Private IP path to PaaS service to reduce public attack surface.
// - Diagnostics: Logs/metrics sent to central monitoring for operations and incident response.
// - SaaS use here: Creates shared monitoring backend used by all SaaS modules.
// -----------------------------------------------------------------------------

// Monitoring baseline module.
// Why: central logs/telemetry are required for ops and security investigation.
targetScope = 'resourceGroup'

@description('Azure region where monitoring resources are deployed.')
param location string
@description('Project prefix used to build stable monitoring resource names.')
param projectPrefix string
@description('Environment identifier (dev/test/prod) included in names and tags.')
param environment string
@minValue(30)
@maxValue(730)
@description('How long logs stay in Log Analytics before automatic purge.')
param retentionInDays int = 30
@description('Common tags applied to monitoring resources.')
param tags object = {}

// Workspace name pattern kept short for Azure naming limits and easy filtering.
var workspaceName = '${projectPrefix}-${environment}-law'
// Application Insights name aligned with workspace naming for correlation.
var appInsightsName = '${projectPrefix}-${environment}-appi'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionInDays
    // Security/governance: use resource-permission model for access.
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    // Workspace-based mode centralizes telemetry and governance.
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsWorkspaceName string = logAnalytics.name
// Connection string is used by apps/agents to send telemetry to this App Insights instance.
output appInsightsConnectionString string = appInsights.properties.ConnectionString
