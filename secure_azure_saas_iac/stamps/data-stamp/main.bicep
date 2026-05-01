// Data/integration stamp for SaaS platform.
// Why: provides secure shared state + messaging baseline aligned to blueprint.
targetScope = 'resourceGroup'

@description('Deployment region.')
param location string

@description('Project prefix used in resource names.')
param projectPrefix string

@description('Environment label used in naming/tagging.')
param environment string

@description('Private endpoint subnet resource ID.')
param privateEndpointSubnetResourceId string
@description('Log Analytics workspace resource ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''
@description('If true, send data-stamp diagnostics to Log Analytics workspace.')
param deployDiagnostics bool = false

@description('Storage SKU, for example Standard_LRS or Standard_GRS.')
param storageSku string = 'Standard_LRS'

@description('Service Bus namespace SKU. Standard is default baseline.')
@allowed([
  'Standard'
  'Premium'
])
param serviceBusSku string = 'Standard'

@description('Default queue name for app messaging.')
param defaultQueueName string = 'app-events'

@description('If true, deploy Event Grid topic with private endpoint.')
param deployEventGrid bool = false

@description('Event Grid topic name (if enabled).')
param eventGridTopicName string = 'app-events-topic'

@description('If true, deploy private Redis cache for app state/performance.')
param deployRedis bool = false

@description('Redis cache name suffix (if enabled).')
param redisNameSuffix string = 'cache'

@description('Redis SKU name.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param redisSkuName string = 'Standard'

@description('Redis SKU family, typically C for Basic/Standard and P for Premium.')
param redisSkuFamily string = 'C'

@description('Redis capacity (size tier index).')
param redisCapacity int = 1

@description('If true, deploy private Azure SQL server + database.')
param deploySql bool = false

@description('SQL server name suffix.')
param sqlServerNameSuffix string = 'sql'

@description('SQL database name.')
param sqlDatabaseName string = 'appdb'

@description('SQL admin login name (required when deploySql=true).')
param sqlAdminLogin string = 'sqladminuser'

@secure()
@description('SQL admin password (required when deploySql=true).')
param sqlAdminPassword string = ''

@description('Tags to apply to all resources.')
param tags object = {}
@description('If true, apply CanNotDelete locks to critical resources in this stamp.')
param applyDeleteLocks bool = false

var storageAccountName = toLower(replace('${projectPrefix}${environment}${uniqueString(resourceGroup().id)}sa', '-', ''))
var serviceBusNamespaceName = toLower(replace('${projectPrefix}-${environment}-${uniqueString(resourceGroup().id)}-sb', '_', '-'))
var vnetResourceId = split(privateEndpointSubnetResourceId, '/subnets/')[0]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    accessTier: 'Hot'
  }
}

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployDiagnostics) {
  scope: storageAccount
  name: 'storage-diagnostics'
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

resource storageLock 'Microsoft.Authorization/locks@2020-05-01' = if (applyDeleteLocks) {
  name: '${storageAccount.name}-delete-lock'
  scope: storageAccount
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects Storage account from accidental deletion.'
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  tags: tags
  sku: {
    name: serviceBusSku
    tier: serviceBusSku
    capacity: serviceBusSku == 'Premium' ? 1 : 0
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: '1.2'
    disableLocalAuth: true
    zoneRedundant: serviceBusSku == 'Premium'
  }
}

resource serviceBusDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployDiagnostics) {
  scope: serviceBusNamespace
  name: 'servicebus-diagnostics'
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

resource serviceBusLock 'Microsoft.Authorization/locks@2020-05-01' = if (applyDeleteLocks) {
  name: '${serviceBusNamespace.name}-delete-lock'
  scope: serviceBusNamespace
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects Service Bus namespace from accidental deletion.'
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2023-01-01-preview' = {
  name: '${serviceBusNamespace.name}/${defaultQueueName}'
  properties: {
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
    requiresDuplicateDetection: false
    enableBatchedOperations: true
  }
}

resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = if (deploySql) {
  name: toLower(replace('${projectPrefix}-${environment}-${sqlServerNameSuffix}', '_', '-'))
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    // Security: force modern transport and disable public endpoint.
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

resource sqlDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deploySql && deployDiagnostics) {
  scope: sqlServer
  name: 'sql-diagnostics'
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

resource sqlServerLock 'Microsoft.Authorization/locks@2020-05-01' = if (deploySql && applyDeleteLocks) {
  name: '${sqlServer.name}-delete-lock'
  scope: sqlServer
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects SQL server from accidental deletion.'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = if (deploySql) {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

resource redisCache 'Microsoft.Cache/Redis@2023-08-01' = if (deployRedis) {
  name: toLower(replace('${projectPrefix}-${environment}-${redisNameSuffix}', '_', '-'))
  location: location
  tags: tags
  properties: {
    sku: {
      name: redisSkuName
      family: redisSkuFamily
      capacity: redisCapacity
    }
    // Security: enforce encrypted transport and no public endpoint.
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    // Security: avoid shared key style auth where clients can use managed identity patterns upstream.
    disableAccessKeyAuthentication: true
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

resource redisDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployRedis && deployDiagnostics) {
  scope: redisCache
  name: 'redis-diagnostics'
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

resource redisLock 'Microsoft.Authorization/locks@2020-05-01' = if (deployRedis && applyDeleteLocks) {
  name: '${redisCache.name}-delete-lock'
  scope: redisCache
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects Redis cache from accidental deletion.'
  }
}

resource eventGridTopic 'Microsoft.EventGrid/topics@2022-06-15' = if (deployEventGrid) {
  name: toLower(replace('${projectPrefix}-${environment}-${eventGridTopicName}', '_', '-'))
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    inputSchema: 'EventGridSchema'
  }
}

resource eventGridDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployEventGrid && deployDiagnostics) {
  scope: eventGridTopic
  name: 'eventgrid-diagnostics'
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

resource eventGridLock 'Microsoft.Authorization/locks@2020-05-01' = if (deployEventGrid && applyDeleteLocks) {
  name: '${eventGridTopic.name}-delete-lock'
  scope: eventGridTopic
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects Event Grid topic from accidental deletion.'
  }
}

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${storageAccount.name}-blob-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-blob-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource serviceBusPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${serviceBusNamespace.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'servicebus-connection'
        properties: {
          privateLinkServiceId: serviceBusNamespace.id
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
  }
}

resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deploySql) {
  name: '${sqlServer.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'sql-connection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource redisPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deployRedis) {
  name: '${redisCache.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'redis-connection'
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
}

resource eventGridPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deployEventGrid) {
  name: '${eventGridTopic.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'eventgrid-connection'
        properties: {
          privateLinkServiceId: eventGridTopic.id
          groupIds: [
            'topic'
          ]
        }
      }
    ]
  }
}

resource storagePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  tags: tags
}

resource serviceBusPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.servicebus.windows.net'
  location: 'global'
  tags: tags
}

resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deploySql) {
  name: 'privatelink.database.windows.net'
  location: 'global'
  tags: tags
}

resource redisPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployRedis) {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  tags: tags
}

resource eventGridPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployEventGrid) {
  name: 'privatelink.eventgrid.azure.net'
  location: 'global'
  tags: tags
}

resource storageDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net/${projectPrefix}-${environment}-blob-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResourceId
    }
  }
}

resource serviceBusDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'privatelink.servicebus.windows.net/${projectPrefix}-${environment}-sb-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResourceId
    }
  }
}

resource sqlDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deploySql) {
  name: 'privatelink.database.windows.net/${projectPrefix}-${environment}-sql-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResourceId
    }
  }
}

resource redisDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployRedis) {
  name: 'privatelink.redis.cache.windows.net/${projectPrefix}-${environment}-redis-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResourceId
    }
  }
}

resource eventGridDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployEventGrid) {
  name: 'privatelink.eventgrid.azure.net/${projectPrefix}-${environment}-eg-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResourceId
    }
  }
}

resource storagePeDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  name: '${storagePrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-dns-config'
        properties: {
          privateDnsZoneId: storagePrivateDnsZone.id
        }
      }
    ]
  }
}

resource serviceBusPeDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  name: '${serviceBusPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sb-dns-config'
        properties: {
          privateDnsZoneId: serviceBusPrivateDnsZone.id
        }
      }
    ]
  }
}

resource sqlPeDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (deploySql) {
  name: '${sqlPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql-dns-config'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}

resource redisPeDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (deployRedis) {
  name: '${redisPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'redis-dns-config'
        properties: {
          privateDnsZoneId: redisPrivateDnsZone.id
        }
      }
    ]
  }
}

resource eventGridPeDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (deployEventGrid) {
  name: '${eventGridPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'eventgrid-dns-config'
        properties: {
          privateDnsZoneId: eventGridPrivateDnsZone.id
        }
      }
    ]
  }
}

output storageAccountName string = storageAccount.name
output serviceBusNamespaceName string = serviceBusNamespace.name
output serviceBusQueueName string = defaultQueueName
output storageAccountId string = storageAccount.id
output serviceBusNamespaceId string = serviceBusNamespace.id
output eventGridTopicResourceId string = deployEventGrid ? eventGridTopic.id : ''
output redisCacheResourceId string = deployRedis ? redisCache.id : ''
output sqlServerResourceId string = deploySql ? sqlServer.id : ''
output sqlDatabaseResourceId string = deploySql ? sqlDatabase.id : ''
