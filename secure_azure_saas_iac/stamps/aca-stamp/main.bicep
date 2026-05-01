// Application stamp module.
// Provisions one secure runtime slice with:
// - Azure Container Apps environment
// - Key Vault + private endpoint
// - user-assigned identities
// - public web app + internal worker app
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
@description('Controls whether the web app is publicly reachable. Keep false unless you intentionally publish internet endpoints.')
param enablePublicWebIngress bool = false
param allowedIngressCidrs array
param tags object = {}

var acaEnvironmentName = '${projectPrefix}-${environment}-acae'
var keyVaultName = toLower(replace('${projectPrefix}-${environment}-${uniqueString(subscription().id, resourceGroup().name)}-kv', '_', '-'))
var webAppName = '${projectPrefix}-${environment}-web'
var workerAppName = '${projectPrefix}-${environment}-worker'
// Derive parent VNet id from subnet id for private DNS zone linking.
var vnetResourceId = split(infrastructureSubnetResourceId, '/subnets/')[0]

// ACA environment attached to delegated subnet and Log Analytics workspace.
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

// Key Vault configured with RBAC, soft-delete, and purge-protection.
// Public network remains enabled but firewalled (default deny), while
// private endpoint is created later in this module for private access.
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
    // Security hardening: disable public endpoint access entirely.
    // Access is forced through private endpoint.
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      // Security hardening: no broad trusted-service bypass.
      // This reduces unintended data-plane exposure.
      bypass: 'None'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// Dedicated identities per app support least-privilege role assignments.
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

// Grant web app identity read-only secret access in Key Vault.
resource kvSecretsUserWeb 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webIdentity.properties.principalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant worker app identity read-only secret access in Key Vault.
resource kvSecretsUserWorker 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, workerIdentity.properties.principalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: workerIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Internet-facing app. CIDR list is parameterized for stricter production controls.
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
        // Security hardening: internal-only by default.
        external: enablePublicWebIngress
        targetPort: 80
        transport: 'auto'
        // Security hardening: when public ingress is enabled, explicitly allow only trusted CIDRs.
        ipSecurityRestrictions: [for cidr in allowedIngressCidrs: {
          // One allow rule generated per CIDR input.
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

// Internal-only worker app for background processing.
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

// Private endpoint maps Key Vault to the private endpoint subnet.
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

// Private DNS zone required so workloads resolve Key Vault hostname to private IP.
resource kvPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

// Link private DNS zone to VNet hosting the ACA environment.
resource kvDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net/${projectPrefix}-${environment}-kv-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResourceId
    }
  }
}

// Attach the private endpoint to the Key Vault private DNS zone.
resource kvPrivateEndpointDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  name: '${kvPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv-dns-config'
        properties: {
          privateDnsZoneId: kvPrivateDnsZone.id
        }
      }
    ]
  }
}

// Operational outputs.
output containerAppsEnvironmentName string = acaEnvironment.name
output webContainerAppFqdn string = webApp.properties.configuration.ingress.fqdn
output keyVaultName string = keyVault.name
