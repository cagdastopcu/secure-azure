// -----------------------------------------------------------------------------
// GLOSSARY + SAAS CONTEXT (DEEP PLAIN-LANGUAGE)
// - IaC: This file defines cloud behavior as auditable text instead of manual clicks.
// - Module: Reusable building block with inputs (parameters) and outputs.
// - Parameter: Value you change per environment without rewriting deployment logic.
// - Resource: Actual Azure service instance created by this file.
// - Output: Exported value used by other modules, tests, or pipeline steps.
// - Identity-first: Prefer managed identities over embedded static credentials.
// - Private-first: Prefer private networking and explicit ingress boundaries.
// - How this file is used in this SaaS project:
//   1. Creates central log and telemetry services.
//   2. Used by app/data/platform modules for diagnostics.
//   3. Inputs: retention days and naming context.
//   4. Outputs: workspace identifiers and telemetry connection values.
//   5. Security role: enables forensic visibility and incident investigation.
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
