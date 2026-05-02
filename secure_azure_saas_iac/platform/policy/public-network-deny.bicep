// -----------------------------------------------------------------------------
// FILE: Custom deny policies for public network access on key PaaS services.
// USED IN SAAS FLOW: Optional hard guardrail layer at subscription scope.
// SECURITY-CRITICAL: Blocks accidental public exposure even if template/application config drifts.
// -----------------------------------------------------------------------------
// Advanced subscription-level policy guardrails.
// Why: block accidental public exposure for core data/services.
targetScope = 'subscription'

@description('Enable deny assignments for public network access on key PaaS resources.')
param enableDeny bool = true

// Custom policy: Storage accounts must disable public network access.
resource storageDenyPolicy 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: 'custom-deny-storage-public-network'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Storage accounts should disable public network access'
    description: 'Deny storage accounts with publicNetworkAccess not set to Disabled.'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            field: 'Microsoft.Storage/storageAccounts/publicNetworkAccess'
            notEquals: 'Disabled'
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

resource sqlDenyPolicy 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: 'custom-deny-sql-public-network'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Azure SQL servers should disable public network access'
    description: 'Deny SQL servers with publicNetworkAccess not set to Disabled.'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Sql/servers'
          }
          {
            field: 'Microsoft.Sql/servers/publicNetworkAccess'
            notEquals: 'Disabled'
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

resource keyVaultDenyPolicy 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: 'custom-deny-keyvault-public-network'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Key Vault should disable public network access'
    description: 'Deny Key Vault with publicNetworkAccess not set to Disabled.'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.KeyVault/vaults'
          }
          {
            field: 'Microsoft.KeyVault/vaults/publicNetworkAccess'
            notEquals: 'Disabled'
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

resource serviceBusDenyPolicy 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: 'custom-deny-servicebus-public-network'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Service Bus should disable public network access'
    description: 'Deny Service Bus namespaces with publicNetworkAccess not set to Disabled.'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.ServiceBus/namespaces'
          }
          {
            field: 'Microsoft.ServiceBus/namespaces/publicNetworkAccess'
            notEquals: 'Disabled'
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

resource eventGridDenyPolicy 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: 'custom-deny-eventgrid-public-network'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Event Grid topics should disable public network access'
    description: 'Deny Event Grid topics with publicNetworkAccess not set to Disabled.'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.EventGrid/topics'
          }
          {
            field: 'Microsoft.EventGrid/topics/publicNetworkAccess'
            notEquals: 'Disabled'
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

resource redisDenyPolicy 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: 'custom-deny-redis-public-network'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Redis should disable public network access'
    description: 'Deny Redis caches with publicNetworkAccess not set to Disabled.'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Cache/Redis'
          }
          {
            field: 'Microsoft.Cache/Redis/publicNetworkAccess'
            notEquals: 'Disabled'
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

resource storageAssign 'Microsoft.Authorization/policyAssignments@2025-03-01' = if (enableDeny) {
  name: 'assign-deny-storage-public-network'
  properties: {
    displayName: 'Deny storage public network access'
    policyDefinitionId: storageDenyPolicy.id
    enforcementMode: 'Default'
  }
}

resource sqlAssign 'Microsoft.Authorization/policyAssignments@2025-03-01' = if (enableDeny) {
  name: 'assign-deny-sql-public-network'
  properties: {
    displayName: 'Deny SQL public network access'
    policyDefinitionId: sqlDenyPolicy.id
    enforcementMode: 'Default'
  }
}

resource keyVaultAssign 'Microsoft.Authorization/policyAssignments@2025-03-01' = if (enableDeny) {
  name: 'assign-deny-keyvault-public-network'
  properties: {
    displayName: 'Deny Key Vault public network access'
    policyDefinitionId: keyVaultDenyPolicy.id
    enforcementMode: 'Default'
  }
}

resource serviceBusAssign 'Microsoft.Authorization/policyAssignments@2025-03-01' = if (enableDeny) {
  name: 'assign-deny-servicebus-public-network'
  properties: {
    displayName: 'Deny Service Bus public network access'
    policyDefinitionId: serviceBusDenyPolicy.id
    enforcementMode: 'Default'
  }
}

resource eventGridAssign 'Microsoft.Authorization/policyAssignments@2025-03-01' = if (enableDeny) {
  name: 'assign-deny-eventgrid-public-network'
  properties: {
    displayName: 'Deny Event Grid public network access'
    policyDefinitionId: eventGridDenyPolicy.id
    enforcementMode: 'Default'
  }
}

resource redisAssign 'Microsoft.Authorization/policyAssignments@2025-03-01' = if (enableDeny) {
  name: 'assign-deny-redis-public-network'
  properties: {
    displayName: 'Deny Redis public network access'
    policyDefinitionId: redisDenyPolicy.id
    enforcementMode: 'Default'
  }
}

output assignmentNames array = enableDeny ? [
  storageAssign.name
  sqlAssign.name
  keyVaultAssign.name
  serviceBusAssign.name
  eventGridAssign.name
  redisAssign.name
] : []
