targetScope = 'resourceGroup'

param location string
param projectPrefix string
param environment string
param logAnalyticsWorkspaceId string
@secure()
param logAnalyticsSharedKey string
param infrastructureSubnetResourceId string
param privateEndpointSubnetResourceId string
param containerImage string
param allowedIngressCidrs array
param tags object = {}

var acaEnvironmentName = '${projectPrefix}-${environment}-acae'
var keyVaultName = toLower(replace('${projectPrefix}-${environment}-${uniqueString(subscription().id, resourceGroup().name)}-kv', '_', '-'))
var webAppName = '${projectPrefix}-${environment}-web'
var workerAppName = '${projectPrefix}-${environment}-worker'

resource acaEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: acaEnvironmentName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetResourceId
      internal: false
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    sku: {
      family: 'A'
      name: 'standard'
    }
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${webAppName}-id'
  location: location
  tags: tags
}

resource workerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${workerAppName}-id'
  location: location
  tags: tags
}

resource kvSecretsUserWeb 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webIdentity.properties.principalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvSecretsUserWorker 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, workerIdentity.properties.principalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: workerIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource webApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: webAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${webIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        ipSecurityRestrictions: [for cidr in allowedIngressCidrs: {
          name: 'allow-${replace(cidr, '/', '-')}'
          action: 'Allow'
          ipAddressRange: cidr
        }]
      }
      activeRevisionsMode: 'Single'
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
      containers: [
        {
          name: 'web'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: webIdentity.properties.clientId
            }
            {
              name: 'KEYVAULT_URI'
              value: keyVault.properties.vaultUri
            }
          ]
        }
      ]
    }
  }
}

resource workerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: workerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${workerIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        external: false
        targetPort: 8080
        transport: 'auto'
      }
      activeRevisionsMode: 'Single'
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 5
      }
      containers: [
        {
          name: 'worker'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: workerIdentity.properties.clientId
            }
            {
              name: 'KEYVAULT_URI'
              value: keyVault.properties.vaultUri
            }
          ]
        }
      ]
    }
  }
}

resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${keyVaultName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyvault-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

output containerAppsEnvironmentName string = acaEnvironment.name
output webContainerAppFqdn string = webApp.properties.configuration.ingress.fqdn
output keyVaultName string = keyVault.name
