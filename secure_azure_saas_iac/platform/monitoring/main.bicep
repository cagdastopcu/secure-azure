targetScope = 'resourceGroup'

param location string
param projectPrefix string
param environment string
@minValue(30)
@maxValue(730)
param retentionInDays int = 30
param tags object = {}

var workspaceName = '${projectPrefix}-${environment}-law'
var appInsightsName = '${projectPrefix}-${environment}-appi'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionInDays
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
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsWorkspaceName string = logAnalytics.name
output logAnalyticsPrimarySharedKey string = listKeys(logAnalytics.id, '2023-09-01').primarySharedKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
