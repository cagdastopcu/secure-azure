// Monitoring baseline module.
// Creates centralized Log Analytics and workspace-based Application Insights.
targetScope = 'resourceGroup'

// Region for monitoring resources.
param location string
// Naming context.
param projectPrefix string
param environment string
@minValue(30)
@maxValue(730)
// Retention bounds enforce baseline observability retention window.
param retentionInDays int = 30
// Governance tags propagated from root.
param tags object = {}

var workspaceName = '${projectPrefix}-${environment}-law'
var appInsightsName = '${projectPrefix}-${environment}-appi'

// Core log store for platform and app telemetry.
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    // PerGB2018 is common pay-as-you-go SKU for log ingestion.
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionInDays
    features: {
      // Security: use RBAC/resource permissions over legacy workspace-level ACL model.
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// App Insights linked to Log Analytics for unified querying.
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    // Web app telemetry profile.
    Application_Type: 'web'
    // Workspace-based mode centralizes telemetry and governance.
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
  }
}

// Outputs used by downstream modules/pipelines.
output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsWorkspaceName string = logAnalytics.name
output logAnalyticsPrimarySharedKey string = listKeys(logAnalytics.id, '2023-09-01').primarySharedKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
