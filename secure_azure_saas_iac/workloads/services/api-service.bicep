// -----------------------------------------------------------------------------
// FILE: Reusable API workload module for Container Apps.
// USED IN SAAS FLOW: Onboards tenant-facing API microservices with consistent runtime settings.
// SECURITY-CRITICAL: Defaults to secure ingress and identity-based cloud access patterns.
// -----------------------------------------------------------------------------
// API service module for SaaS workloads.
// Why: reusable secure baseline for HTTP API services on Azure Container Apps.
targetScope = 'resourceGroup'

@description('Deployment region.')
param location string

@description('Container App name for API service.')
param appName string

@description('Container image for API service.')
param image string

@description('Container Apps managed environment resource ID.')
param managedEnvironmentId string

@description('User-assigned identity resource ID for API app.')
param userAssignedIdentityResourceId string

@description('Client ID of user-assigned identity (for AZURE_CLIENT_ID env var).')
param userAssignedIdentityClientId string

@description('Enable public ingress only when internet exposure is required.')
param enablePublicIngress bool = false

@description('Allowed source CIDRs when public ingress is enabled.')
param allowedIngressCidrs array = []

@description('Target container port.')
param targetPort int = 8080

@description('Minimum replicas.')
param minReplicas int = 1

@description('Maximum replicas.')
param maxReplicas int = 10

@description('CPU cores for container.')
param cpu string = '0.5'

@description('Memory for container, e.g. 1Gi.')
param memory string = '1Gi'

@description('Optional Key Vault URI passed as env var.')
param keyVaultUri string = ''

@description('Optional extra environment variables.')
param extraEnv array = []

@description('Tags to apply.')
param tags object = {}

resource apiApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironmentId
    configuration: {
      ingress: {
        // Security: default private ingress unless explicitly enabled.
        external: enablePublicIngress
        // Security: require HTTPS.
        allowInsecure: false
        targetPort: targetPort
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
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
      containers: [
        {
          name: 'api'
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: concat([
            {
              name: 'AZURE_CLIENT_ID'
              value: userAssignedIdentityClientId
            }
            {
              name: 'KEYVAULT_URI'
              value: keyVaultUri
            }
          ], extraEnv)
        }
      ]
    }
  }
}

output appResourceId string = apiApp.id
output appFqdn string = apiApp.properties.configuration.ingress.fqdn
