// API Management baseline module.
// Why: blueprint calls for optional centralized API gateway for governance, productization, and throttling policies.
targetScope = 'resourceGroup'

@description('Deployment region.')
param location string

@description('Project prefix used in naming.')
param projectPrefix string

@description('Environment label used in naming/tagging.')
param environment string

@description('API Management publisher display name.')
param publisherName string

@description('API Management publisher email.')
param publisherEmail string

@description('API Management SKU name.')
@allowed([
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Developer'

@description('API Management SKU capacity/units.')
param skuCapacity int = 1

@description('If true, send APIM logs and metrics to Log Analytics.')
param deployDiagnostics bool = true

@description('Log Analytics workspace resource ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to APIM resources.')
param tags object = {}

var apiManagementServiceName = toLower(replace('${projectPrefix}-${environment}-${uniqueString(resourceGroup().id)}-apim', '_', '-'))

resource apiManagementService 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apiManagementServiceName
  location: location
  tags: tags
  identity: {
    // Security: built-in managed identity enables secretless access patterns.
    type: 'SystemAssigned'
  }
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
    virtualNetworkType: 'None'
    // Security: disable legacy and weak transport protocols/ciphers.
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'true'
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource apimDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployDiagnostics && logAnalyticsWorkspaceId != '') {
  scope: apiManagementService
  name: 'apim-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output apiManagementServiceName string = apiManagementService.name
output apiManagementServiceId string = apiManagementService.id
output apiManagementGatewayUrl string = apiManagementService.properties.gatewayUrl
