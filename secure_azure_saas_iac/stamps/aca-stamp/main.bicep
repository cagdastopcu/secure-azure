// -----------------------------------------------------------------------------
// TERM GLOSSARY (this file)
// - ARM: Azure Resource Manager control plane that applies deployments.
// - Bicep: Declarative language compiled to ARM templates.
// - Resource Group (RG): Logical container for Azure resources.
// - Parameter: Runtime input value passed into template/module.
// - Module: Reusable Bicep file invoked from another template.
// - Output: Exported value from a template/module.
// - RBAC: Role-Based Access Control authorization model.
// - Managed Identity: Azure-managed service identity without embedded secrets.
// - Private Endpoint: Private IP path to an Azure PaaS service.
// - Private DNS Zone: DNS mapping so service names resolve to private IPs.
// -----------------------------------------------------------------------------// Extra terms used in ACA stamp file:
// - ACA: Azure Container Apps managed container runtime.
// - Managed Environment: Shared ACA runtime boundary for container apps.
// - Workload Profile: Compute profile (e.g., Consumption) for ACA workloads.
// - Key Vault: Secret/key/certificate store.
// - Purge Protection: Prevents immediate permanent deletion of vault objects.
// - Soft Delete: Recoverable delete window before permanent removal.
// - Private Link groupId 'vault': Key Vault private endpoint subresource.
// Application stamp module.
// Provisions one secure runtime slice with:
// - Azure Container Apps environment
// - Key Vault + private endpoint
// - user-assigned identities
// - public web app + internal worker app
// What: sets deployment scope. Why: controls where ARM can deploy this file.
// Sets where this template is allowed to deploy (resource group scope here).
targetScope = 'resourceGroup'

// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param location string
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param projectPrefix string
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param environment string
// Resource ID of centralized Log Analytics workspace used by ACA environment logs.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param logAnalyticsWorkspaceId string
// What: marks next input as secret. Why: reduces secret leakage in deployment outputs.
// Marks the next input as secret so Azure hides it in deployment output.
@secure()
// Shared key is sensitive; secure() prevents accidental plaintext exposure in deployment metadata.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param logAnalyticsSharedKey string
// Subnet delegated to ACA managed environment infrastructure.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param infrastructureSubnetResourceId string
// Subnet dedicated for private endpoint NIC placement.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param privateEndpointSubnetResourceId string
// Image URI for both web and worker containers in this baseline stamp.
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param containerImage string
// What: parameter description text. Why: helps humans understand inputs in tools.
// Description shown in tools so you know what the next input is for.
@description('Controls whether the web app is publicly reachable. Keep false unless you intentionally publish internet endpoints.')
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param enablePublicWebIngress bool = false
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param allowedIngressCidrs array
// What: declares an input parameter. Why: lets you customize deployment behavior.
// Defines an input value you can change when deploying.
param tags object = {}

// What: declares helper value. Why: reuse computed values and keep names consistent.
// Creates a helper value used later to avoid repeating long expressions.
var acaEnvironmentName = '${projectPrefix}-${environment}-acae'
// What: declares helper value. Why: reuse computed values and keep names consistent.
// Creates a helper value used later to avoid repeating long expressions.
var keyVaultName = toLower(replace('${projectPrefix}-${environment}-${uniqueString(subscription().id, resourceGroup().name)}-kv', '_', '-'))
// What: declares helper value. Why: reuse computed values and keep names consistent.
// Creates a helper value used later to avoid repeating long expressions.
var webAppName = '${projectPrefix}-${environment}-web'
// What: declares helper value. Why: reuse computed values and keep names consistent.
// Creates a helper value used later to avoid repeating long expressions.
var workerAppName = '${projectPrefix}-${environment}-worker'
// Derive parent VNet id from subnet id for private DNS zone linking.
// What: declares helper value. Why: reuse computed values and keep names consistent.
// Creates a helper value used later to avoid repeating long expressions.
var vnetResourceId = split(infrastructureSubnetResourceId, '/subnets/')[0]

// ACA environment attached to delegated subnet and Log Analytics workspace.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource acaEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: acaEnvironmentName
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: location
  // What: starts tags block. Why: ownership, cost, and governance metadata.
  // Starts tags used for ownership, cost, and governance filtering.
  tags: tags
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetResourceId
      internal: false
    // What: close current settings block.
    // Ends the current object block.
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: logAnalyticsSharedKey
      // What: close current settings block.
      // Ends the current object block.
      }
    // What: close current settings block.
    // Ends the current object block.
    }
    workloadProfiles: [
      // What: open nested settings block.
      // Starts a nested object block.
      {
        // What: sets resource/object name. Why: identifier used by Azure for this object.
        // Sets the name Azure will use for this item.
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      // What: close current settings block.
      // Ends the current object block.
      }
    // What: end of the list started above.
    // Ends the list started above.
    ]
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Key Vault configured with RBAC, soft-delete, and purge-protection.
// Public network is disabled; private endpoint path is enforced.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: keyVaultName
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: location
  // What: starts tags block. Why: ownership, cost, and governance metadata.
  // Starts tags used for ownership, cost, and governance filtering.
  tags: tags
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    tenantId: subscription().tenantId
    // Security: uses roles/permissions instead of old access policy model.
    // What: enables RBAC data-plane auth. Why: central role-based permission model.
    // Uses RBAC roles for Key Vault access control (modern recommended model).
    enableRbacAuthorization: true
    // Soft-delete is enabled by default for modern Key Vaults; retention window is set below.
    // Security: protects secrets from being permanently deleted right away.
    // What: enables purge protection. Why: prevents immediate permanent deletion.
    // Prevents immediate permanent deletion of Key Vault data.
    enablePurgeProtection: true
    // What: sets soft-delete retention days. Why: recovery window after accidental delete.
    // Keeps deleted vault items recoverable for this many days.
    softDeleteRetentionInDays: 90
    sku: {
      family: 'A'
      // What: sets resource/object name. Why: identifier used by Azure for this object.
      // Sets the name Azure will use for this item.
      name: 'standard'
    // What: close current settings block.
    // Ends the current object block.
    }
    // Security hardening: disable public endpoint access entirely.
    // Access is forced through private endpoint.
    // Security: controls whether this service is reachable from the internet.
    // What: public network toggle. Why: key control for internet exposure.
    // Security setting that controls if public internet access is allowed.
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      // Security hardening: no broad trusted-service bypass.
      // What: firewall bypass behavior. Why: controls trusted service exceptions.
      // Firewall bypass exceptions; None means no broad trusted-service shortcut.
      bypass: 'None'
      // What: firewall default action. Why: Deny-by-default is safer baseline.
      // Firewall default action; Deny means block unless explicitly allowed.
      defaultAction: 'Deny'
      // Explicitly empty lists to avoid accidental broad rules via inheritance assumptions.
      ipRules: []
      virtualNetworkRules: []
    // What: close current settings block.
    // Ends the current object block.
    }
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Dedicated identities per app support least-privilege role assignments.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: '${webAppName}-id'
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: location
  // What: starts tags block. Why: ownership, cost, and governance metadata.
  // Starts tags used for ownership, cost, and governance filtering.
  tags: tags
// What: close current settings block.
// Ends the current object block.
}

// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource workerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: '${workerAppName}-id'
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: location
  // What: starts tags block. Why: ownership, cost, and governance metadata.
  // Starts tags used for ownership, cost, and governance filtering.
  tags: tags
// What: close current settings block.
// Ends the current object block.
}

// Grant web app identity read-only secret access in Key Vault.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource kvSecretsUserWeb 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: guid(keyVault.id, webIdentity.properties.principalId, 'KeyVaultSecretsUser')
  scope: keyVault
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    // Security: chooses the minimum role needed.
    // What: RBAC role id. Why: selects exact permission set to grant.
    // Specifies exactly which RBAC role permissions are granted.
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    // What: principal target id. Why: grants role only to intended identity.
    // Specifies which identity receives the RBAC role.
    principalId: webIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Grant worker app identity read-only secret access in Key Vault.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource kvSecretsUserWorker 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: guid(keyVault.id, workerIdentity.properties.principalId, 'KeyVaultSecretsUser')
  scope: keyVault
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    // Security: chooses the minimum role needed.
    // What: RBAC role id. Why: selects exact permission set to grant.
    // Specifies exactly which RBAC role permissions are granted.
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    // What: principal target id. Why: grants role only to intended identity.
    // Specifies which identity receives the RBAC role.
    principalId: workerIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Internet-facing app. CIDR list is parameterized for stricter production controls.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource webApp 'Microsoft.App/containerApps@2025-01-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: webAppName
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: location
  // What: starts tags block. Why: ownership, cost, and governance metadata.
  // Starts tags used for ownership, cost, and governance filtering.
  tags: tags
  // What: starts managed identity block. Why: app auth without embedded secrets.
  // Starts managed identity settings so apps can auth without stored secrets.
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${webIdentity.id}': {}
    // What: close current settings block.
    // Ends the current object block.
    }
  // What: close current settings block.
  // Ends the current object block.
  }
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    // Binds this app to the ACA environment where it runs.
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        // Security hardening: internal-only by default.
        // What: ingress exposure mode. Why: true=public, false=internal-only.
        // Controls if app ingress is public (true) or internal-only (false).
        external: enablePublicWebIngress
        // Security hardening: reject plain HTTP and force TLS at ingress edge.
        // Security: forces encrypted HTTPS instead of plain HTTP.
        // What: insecure HTTP toggle. Why: false enforces encrypted HTTPS.
        // Security setting: false blocks plain HTTP and forces encrypted ingress.
        allowInsecure: false
        // What: app target port. Why: ingress forwards traffic to this container port.
        // Traffic will be forwarded to this container port.
        targetPort: 80
        transport: 'auto'
        // Security hardening: when public ingress is enabled, explicitly allow only trusted CIDRs.
        // What: ingress IP allow-list. Why: limits who can reach endpoint.
        // Starts ingress IP allow-list rules to restrict who can access endpoint.
        ipSecurityRestrictions: [for cidr in allowedIngressCidrs: {
          // One allow rule generated per CIDR input.
          // What: sets resource/object name. Why: identifier used by Azure for this object.
          // Sets the name Azure will use for this item.
          name: 'allow-${replace(cidr, '/', '-')}'
          action: 'Allow'
          ipAddressRange: cidr
        }]
      // What: close current settings block.
      // Ends the current object block.
      }
      activeRevisionsMode: 'Single'
    // What: close current settings block.
    // Ends the current object block.
    }
    template: {
      scale: {
        // Non-zero baseline replica keeps endpoint warm; tune for cost/perf needs.
        minReplicas: 1
        maxReplicas: 10
      // What: close current settings block.
      // Ends the current object block.
      }
      containers: [
        // What: open nested settings block.
        // Starts a nested object block.
        {
          // What: sets resource/object name. Why: identifier used by Azure for this object.
          // Sets the name Azure will use for this item.
          name: 'web'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          // What: close current settings block.
          // Ends the current object block.
          }
          env: [
            // What: open nested settings block.
            // Starts a nested object block.
            {
              // What: sets resource/object name. Why: identifier used by Azure for this object.
              // Sets the name Azure will use for this item.
              name: 'AZURE_CLIENT_ID'
              // What: assigns concrete value. Why: supplies parameter/setting used by Azure.
              value: webIdentity.properties.clientId
            // What: close current settings block.
            // Ends the current object block.
            }
            // What: open nested settings block.
            // Starts a nested object block.
            {
              // What: sets resource/object name. Why: identifier used by Azure for this object.
              // Sets the name Azure will use for this item.
              name: 'KEYVAULT_URI'
              // What: assigns concrete value. Why: supplies parameter/setting used by Azure.
              value: keyVault.properties.vaultUri
            // What: close current settings block.
            // Ends the current object block.
            }
          // What: end of the list started above.
          // Ends the list started above.
          ]
        // What: close current settings block.
        // Ends the current object block.
        }
      // What: end of the list started above.
      // Ends the list started above.
      ]
    // What: close current settings block.
    // Ends the current object block.
    }
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Internal-only worker app for background processing.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource workerApp 'Microsoft.App/containerApps@2025-01-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: workerAppName
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: location
  // What: starts tags block. Why: ownership, cost, and governance metadata.
  // Starts tags used for ownership, cost, and governance filtering.
  tags: tags
  // What: starts managed identity block. Why: app auth without embedded secrets.
  // Starts managed identity settings so apps can auth without stored secrets.
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${workerIdentity.id}': {}
    // What: close current settings block.
    // Ends the current object block.
    }
  // What: close current settings block.
  // Ends the current object block.
  }
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    // Binds this app to the ACA environment where it runs.
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        // Worker path is never internet-facing in this baseline.
        // What: ingress exposure mode. Why: true=public, false=internal-only.
        // Controls if app ingress is public (true) or internal-only (false).
        external: false
        // Security hardening: even internal ingress should enforce encrypted transport semantics.
        // Security: forces encrypted HTTPS instead of plain HTTP.
        // What: insecure HTTP toggle. Why: false enforces encrypted HTTPS.
        // Security setting: false blocks plain HTTP and forces encrypted ingress.
        allowInsecure: false
        // What: app target port. Why: ingress forwards traffic to this container port.
        // Traffic will be forwarded to this container port.
        targetPort: 8080
        transport: 'auto'
      // What: close current settings block.
      // Ends the current object block.
      }
      activeRevisionsMode: 'Single'
    // What: close current settings block.
    // Ends the current object block.
    }
    template: {
      scale: {
        // Conservative worker scaling defaults; adjust to queue/workload behavior.
        minReplicas: 1
        maxReplicas: 5
      // What: close current settings block.
      // Ends the current object block.
      }
      containers: [
        // What: open nested settings block.
        // Starts a nested object block.
        {
          // What: sets resource/object name. Why: identifier used by Azure for this object.
          // Sets the name Azure will use for this item.
          name: 'worker'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          // What: close current settings block.
          // Ends the current object block.
          }
          env: [
            // What: open nested settings block.
            // Starts a nested object block.
            {
              // What: sets resource/object name. Why: identifier used by Azure for this object.
              // Sets the name Azure will use for this item.
              name: 'AZURE_CLIENT_ID'
              // What: assigns concrete value. Why: supplies parameter/setting used by Azure.
              value: workerIdentity.properties.clientId
            // What: close current settings block.
            // Ends the current object block.
            }
            // What: open nested settings block.
            // Starts a nested object block.
            {
              // What: sets resource/object name. Why: identifier used by Azure for this object.
              // Sets the name Azure will use for this item.
              name: 'KEYVAULT_URI'
              // What: assigns concrete value. Why: supplies parameter/setting used by Azure.
              value: keyVault.properties.vaultUri
            // What: close current settings block.
            // Ends the current object block.
            }
          // What: end of the list started above.
          // Ends the list started above.
          ]
        // What: close current settings block.
        // Ends the current object block.
        }
      // What: end of the list started above.
      // Ends the list started above.
      ]
    // What: close current settings block.
    // Ends the current object block.
    }
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Private endpoint maps Key Vault to the private endpoint subnet.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: '${keyVaultName}-pe'
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: location
  // What: starts tags block. Why: ownership, cost, and governance metadata.
  // Starts tags used for ownership, cost, and governance filtering.
  tags: tags
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    // What: close current settings block.
    // Ends the current object block.
    }
    privateLinkServiceConnections: [
      // What: open nested settings block.
      // Starts a nested object block.
      {
        // What: sets resource/object name. Why: identifier used by Azure for this object.
        // Sets the name Azure will use for this item.
        name: 'keyvault-connection'
        // What: starts service settings block. Why: this is where behavior/security is configured.
        // Starts the main behavior/settings block for this resource.
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          // What: end of the list started above.
          // Ends the list started above.
          ]
        // What: close current settings block.
        // Ends the current object block.
        }
      // What: close current settings block.
      // Ends the current object block.
      }
    // What: end of the list started above.
    // Ends the list started above.
    ]
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Private DNS zone required so workloads resolve Key Vault hostname to private IP.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource kvPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: 'privatelink.vaultcore.azure.net'
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: 'global'
  // What: starts tags block. Why: ownership, cost, and governance metadata.
  // Starts tags used for ownership, cost, and governance filtering.
  tags: tags
// What: close current settings block.
// Ends the current object block.
}

// Link private DNS zone to VNet hosting the ACA environment.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource kvDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: 'privatelink.vaultcore.azure.net/${projectPrefix}-${environment}-kv-dns-link'
  // What: sets Azure region/location metadata. Why: controls region placement.
  // Sets the Azure region for this resource/assignment metadata.
  location: 'global'
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResourceId
    // What: close current settings block.
    // Ends the current object block.
    }
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Attach the private endpoint to the Key Vault private DNS zone.
// What: declares Azure resource. Why: this is what ARM will create/manage.
// Starts a real Azure resource declaration.
resource kvPrivateEndpointDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  // What: sets resource/object name. Why: identifier used by Azure for this object.
  // Sets the name Azure will use for this item.
  name: '${kvPrivateEndpoint.name}/default'
  // What: starts service settings block. Why: this is where behavior/security is configured.
  // Starts the main behavior/settings block for this resource.
  properties: {
    privateDnsZoneConfigs: [
      // What: open nested settings block.
      // Starts a nested object block.
      {
        // What: sets resource/object name. Why: identifier used by Azure for this object.
        // Sets the name Azure will use for this item.
        name: 'kv-dns-config'
        // What: starts service settings block. Why: this is where behavior/security is configured.
        // Starts the main behavior/settings block for this resource.
        properties: {
          // What: private DNS zone link. Why: private endpoint name resolves to private IP.
          // Links private endpoint DNS so service name resolves to private IP.
          privateDnsZoneId: kvPrivateDnsZone.id
        // What: close current settings block.
        // Ends the current object block.
        }
      // What: close current settings block.
      // Ends the current object block.
      }
    // What: end of the list started above.
    // Ends the list started above.
    ]
  // What: close current settings block.
  // Ends the current object block.
  }
// What: close current settings block.
// Ends the current object block.
}

// Operational outputs.
// What: exports value. Why: gives useful post-deploy values to users/other modules.
// Returns a value after deployment for operators or other modules.
output containerAppsEnvironmentName string = acaEnvironment.name
// What: exports value. Why: gives useful post-deploy values to users/other modules.
// Returns a value after deployment for operators or other modules.
output webContainerAppFqdn string = webApp.properties.configuration.ingress.fqdn
// What: exports value. Why: gives useful post-deploy values to users/other modules.
// Returns a value after deployment for operators or other modules.
output keyVaultName string = keyVault.name






