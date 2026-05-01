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

@description('Tags to apply to all resources.')
param tags object = {}

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
