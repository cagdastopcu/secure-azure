// -----------------------------------------------------------------------------
// GLOSSARY + SAAS CONTEXT (DEEP PLAIN-LANGUAGE)
// - IaC: This file defines cloud behavior as auditable text instead of manual clicks.
// - Module: Reusable building block with inputs (parameters) and outputs.
// - Parameter: Value you change per environment without rewriting deployment logic.
// - Resource: Actual Azure service instance created by this file.
// - Output: Exported value used by other modules, tests, or pipeline steps.
// - Identity-first: Prefer managed identities over embedded static credentials.
// - Private-first: Prefer private networking and explicit ingress boundaries.
// - How this file is used in this SaaS project:
//   1. Reusable internal service module for tenant onboarding.
//   2. Used for provisioning and tenant lifecycle workflows.
//   3. Inputs: image, environment ID, identity, scaling values.
//   4. Outputs: app resource ID and runtime FQDN.
//   5. Security role: internal-only ingress and managed identity auth path.
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
