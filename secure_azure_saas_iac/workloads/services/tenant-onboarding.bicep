// -----------------------------------------------------------------------------
// GLOSSARY + SAAS CONTEXT
// - IaC: Infrastructure as Code; cloud resources are defined as versioned text files.
// - Module: Reusable deployment unit with parameters and outputs.
// - Parameter: Input value used to customize deployment per SaaS environment.
// - Resource: Azure object created by this file.
// - Output: Value exported for other modules/tests/pipelines.
// - Least privilege: Grant identities only permissions they strictly need.
// - Private endpoint: Private IP path to PaaS service to reduce public attack surface.
// - Diagnostics: Logs/metrics sent to central monitoring for operations and incident response.
// - SaaS use here: Deploys internal tenant-onboarding service used by SaaS provisioning flows.
// -----------------------------------------------------------------------------

// Tenant onboarding service module.
// Why: secure internal service for provisioning tenant resources/workflows.
targetScope = 'resourceGroup'

@description('Deployment region.')
param location string

@description('Container App name for tenant onboarding service.')
param appName string

@description('Container image for tenant onboarding service.')
param image string

@description('Container Apps managed environment resource ID.')
param managedEnvironmentId string

@description('User-assigned identity resource ID.')
param userAssignedIdentityResourceId string

@description('Client ID of user-assigned identity.')
param userAssignedIdentityClientId string

@description('Target container port.')
param targetPort int = 8080

@description('Minimum replicas.')
param minReplicas int = 1

@description('Maximum replicas.')
param maxReplicas int = 5

@description('CPU cores for container.')
param cpu string = '0.5'

@description('Memory for container.')
param memory string = '1Gi'

@description('Optional Key Vault URI passed as env var.')
param keyVaultUri string = ''

@description('Optional extra environment variables.')
param extraEnv array = []

@description('Tags to apply.')
param tags object = {}

resource onboardingApp 'Microsoft.App/containerApps@2025-01-01' = {
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
        // Security: onboarding service is internal-only by default.
        external: false
        allowInsecure: false
        targetPort: targetPort
        transport: 'auto'
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
          name: 'tenant-onboarding'
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

output appResourceId string = onboardingApp.id
output appFqdn string = onboardingApp.properties.configuration.ingress.fqdn
