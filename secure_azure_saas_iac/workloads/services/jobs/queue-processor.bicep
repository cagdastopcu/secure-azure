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
// - SaaS use here: Deploys event-driven background worker for asynchronous SaaS workloads.
// -----------------------------------------------------------------------------

// Queue processor job module.
// Why: reusable secure background worker using Container Apps Job + managed identity.
targetScope = 'resourceGroup'

@description('Deployment region.')
param location string

@description('Container Apps Job name.')
param jobName string

@description('Container image for worker job.')
param image string

@description('Container Apps managed environment resource ID.')
param managedEnvironmentId string

@description('User-assigned identity resource ID for job runtime auth.')
param userAssignedIdentityResourceId string

@description('Client ID of user-assigned identity.')
param userAssignedIdentityClientId string

@description('Service Bus queue name (used by scaler and env var).')
param queueName string

@description('Service Bus namespace FQDN, e.g. namespace.servicebus.windows.net.')
param serviceBusNamespace string

@description('Parallelism for job execution.')
param parallelism int = 1

@description('Replica completion count per execution.')
param replicaCompletionCount int = 1

@description('Replica timeout in seconds.')
param replicaTimeout int = 1800

@description('Replica retry limit.')
param replicaRetryLimit int = 3

@description('Min executions for event trigger.')
param minExecutions int = 0

@description('Max executions for event trigger.')
param maxExecutions int = 10

@description('CPU cores for job container.')
param cpu string = '0.25'

@description('Memory for job container.')
param memory string = '0.5Gi'

@description('Optional Key Vault URI passed as env var.')
param keyVaultUri string = ''

@description('Optional extra environment variables.')
param extraEnv array = []

@description('Tags to apply.')
param tags object = {}

resource queueJob 'Microsoft.App/jobs@2025-01-01' = {
  name: jobName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    environmentId: managedEnvironmentId
    configuration: {
      // Event-driven execution from queue depth.
      triggerType: 'Event'
      eventTriggerConfig: {
        replicaCompletionCount: replicaCompletionCount
        parallelism: parallelism
        scale: {
          minExecutions: minExecutions
          maxExecutions: maxExecutions
          rules: [
            {
              name: 'service-bus-queue'
              type: 'azure-servicebus'
              metadata: {
                namespace: serviceBusNamespace
                queueName: queueName
                messageCount: '5'
              }
              auth: [
                {
                  triggerParameter: 'identity'
                  identity: userAssignedIdentityResourceId
                }
              ]
            }
          ]
        }
      }
      replicaTimeout: replicaTimeout
      replicaRetryLimit: replicaRetryLimit
    }
    template: {
      containers: [
        {
          name: 'queue-processor'
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
              name: 'QUEUE_NAME'
              value: queueName
            }
            {
              name: 'SERVICEBUS_NAMESPACE'
              value: serviceBusNamespace
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

output jobResourceId string = queueJob.id
