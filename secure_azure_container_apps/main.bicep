// This template is intentionally verbose so you can learn Azure Container Apps with secure defaults.
// It deploys a complete baseline in one file: Log Analytics, optional VNet, Container Apps environment,
// optional ACR, a secure app, and an optional scheduled background job.
// Source basis: Microsoft Learn docs for Container Apps ingress, managed identities, jobs, and networking.

targetScope = 'resourceGroup'

// Location is where all resources are created.
@description('Azure region for all resources. Keep resources in the same region to reduce latency and simplify operations.')
param location string = resourceGroup().location

// A short prefix is reused in resource names.
@description('Short naming prefix used in resource names (for example: saasdev, academo).')
@minLength(3)
@maxLength(18)
param prefix string = 'acasecure'

// Common tags help cost tracking, ownership, and governance.
@description('Resource tags applied to every supported resource.')
param tags object = {
  workload: 'azure-container-apps-learning'
  owner: 'platform-team'
  environment: 'dev'
  securityBaseline: 'enabled'
}

// ------------------------------
// Observability (required baseline)
// ------------------------------

@description('Log Analytics workspace name used by the Container Apps environment.')
param logAnalyticsWorkspaceName string = '${prefix}-law'

// ------------------------------
// Networking and environment options
// ------------------------------

@description('Container Apps environment name.')
param containerAppsEnvironmentName string = '${prefix}-aca-env'

@description('If true, creates a dedicated VNet and infrastructure subnet for the environment. Recommended for strong network control.')
param deployVirtualNetwork bool = true

@description('Virtual network name used when deployVirtualNetwork is true.')
param virtualNetworkName string = '${prefix}-vnet'

@description('Subnet name dedicated to Azure Container Apps environment infrastructure.')
param infrastructureSubnetName string = 'aca-infra-snet'

@description('CIDR for infrastructure subnet. Keep this large enough for growth. For broad compatibility, /23 is used as default.')
param infrastructureSubnetPrefix string = '10.42.0.0/23'

@description('If true, the environment uses internal load balancer mode. This removes direct internet exposure at the environment edge.')
param internalLoadBalancer bool = true

@description('Enable zone redundancy for higher resilience (region and quota dependent).')
param zoneRedundant bool = false

@description('Optional workload profiles for advanced sizing/isolation. Empty array means platform default behavior.')
param workloadProfiles array = []

// ------------------------------
// Identity and registry options
// ------------------------------

@description('Create a user-assigned managed identity (UAMI). UAMI is reusable across apps and survives app deletion.')
param createUserAssignedIdentity bool = true

@description('Name of user-assigned managed identity when createUserAssignedIdentity is true.')
param userAssignedIdentityName string = '${prefix}-uami'

@description('Enable system-assigned managed identity on the app. Keep this true unless you have a specific reason not to.')
param useSystemAssignedIdentity bool = true

@description('Create Azure Container Registry (ACR) with hardened defaults.')
param deployContainerRegistry bool = true

@description('ACR name must be globally unique, 5-50 chars, alphanumeric. We build one from prefix + unique string.')
param containerRegistryName string = toLower(replace('${prefix}acr${uniqueString(subscription().id, resourceGroup().id)}', '-', ''))

@description('If true, the app config includes registry auth via managed identity and assigns AcrPull role.')
param usePrivateRegistry bool = true

@description('Container image used by the primary app. Use ACR image when private registry is enabled.')
param appImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

// ------------------------------
// Primary app options
// ------------------------------

@description('Primary secure container app name.')
param containerAppName string = '${prefix}-api'

@description('Expose public ingress for the app. Secure default is false (internal-only ingress).')
param enableExternalIngress bool = false

@description('Container port that receives HTTP traffic from ingress.')
param targetPort int = 8080

@description('Number of replicas that must stay running. Set >=2 for better resilience in production.')
@minValue(1)
param minReplicas int = 2

@description('Maximum replicas allowed for autoscaling.')
@minValue(1)
param maxReplicas int = 10

@description('CPU cores for app container (examples: 0.25, 0.5, 1.0). String is converted with any() for API compatibility.')
param appCpuCores string = '0.5'

@description('Memory for app container (examples: 0.5Gi, 1Gi, 2Gi).')
param appMemory string = '1Gi'

@description('Enable Dapr sidecar configuration for service-to-service calls and pub/sub patterns.')
param enableDapr bool = false

@description('Dapr app id. Required only when enableDapr is true.')
param daprAppId string = '${prefix}-api'

@description('Optional IP restriction rules for ingress. Leave empty to allow all reachable sources.')
param ipSecurityRestrictions array = []

// Secret strategy: prefer Key Vault reference, avoid plaintext values.
@description('Versionless Key Vault secret URI for app secret (recommended), for example: https://mykv.vault.azure.net/secrets/db-password')
param keyVaultSecretUrl string = ''

@description('Fallback inline secret value when Key Vault is not used. Keep empty in real environments.')
@secure()
param inlineSecretValue string = ''

// ------------------------------
// Optional scheduled job options
// ------------------------------

@description('Deploy a sample scheduled Container Apps job for background tasks.')
param deployScheduledJob bool = true

@description('Job name.')
param jobName string = '${prefix}-cleanup-job'

@description('Job container image.')
param jobImage string = 'mcr.microsoft.com/k8se/quickstart-jobs:latest'

@description('Cron expression for scheduled job trigger. Example: */15 * * * * for every 15 minutes.')
param jobCronExpression string = '0 */6 * * *'

@description('Job retry limit per execution.')
@minValue(0)
param jobReplicaRetryLimit int = 2

@description('Job timeout per execution in seconds.')
@minValue(30)
param jobReplicaTimeout int = 900

// ------------------------------
// Derived values
// ------------------------------

// Safety guard: if both identity toggles are turned off, force system identity so security features still work.
// Why this matters: without any identity, you cannot securely pull private images using Entra auth
// and you cannot read Key Vault references without static credentials.
var safeSystemAssignedIdentity = (!createUserAssignedIdentity && !useSystemAssignedIdentity) ? true : useSystemAssignedIdentity

// This decides which identity mode the app will use.
// SystemAssigned,UserAssigned = both identities active on the same resource.
// UserAssigned = reusable identity only.
// SystemAssigned = per-resource identity only.
var appIdentityType = createUserAssignedIdentity && safeSystemAssignedIdentity
  ? 'SystemAssigned,UserAssigned'
  : createUserAssignedIdentity
      ? 'UserAssigned'
      : 'SystemAssigned'

// This object maps user-assigned identity IDs when enabled.
// ARM/Bicep expects this shape: { "<identityResourceId>": {} }.
var userAssignedIdentityMap = createUserAssignedIdentity ? {
  '${userAssignedIdentity.id}': {}
} : {}

// This chooses which identity is used when pulling from ACR and reading Key Vault references.
// If UAMI exists, use it explicitly. Otherwise fall back to system identity.
var identityReferenceForSecretsAndRegistry = createUserAssignedIdentity ? userAssignedIdentity.id : 'system'

// Base ingress configuration keeps HTTP insecure mode disabled (HTTPS redirection/enforcement behavior).
// `external` controls internet exposure (false = internal-only app).
// `targetPort` is the port in the container receiving traffic.
// `transport` auto lets platform choose optimal HTTP mode.
// `allowInsecure: false` blocks plain HTTP access.
// `traffic` sends 100% to latest revision in single-revision mode.
// `ipSecurityRestrictions` lets you add allow/deny source CIDR controls.
var ingressConfiguration = {
  external: enableExternalIngress
  targetPort: targetPort
  transport: 'auto'
  allowInsecure: false
  traffic: [
    {
      latestRevision: true
      weight: 100
    }
  ]
  ipSecurityRestrictions: ipSecurityRestrictions
}

// Dapr block is merged only when requested so deployments stay minimal by default.
// Dapr is optional because not every workload needs sidecar service invocation/pub-sub.
var daprConfiguration = enableDapr ? {
  dapr: {
    enabled: true
    appId: daprAppId
    appPort: targetPort
    appProtocol: 'http'
  }
} : {}

// Secret list prefers Key Vault reference. Inline secret is only fallback for demos/labs.
// Path 1 (recommended): pull secret from Key Vault at runtime using managed identity.
// Path 2 (fallback): store secret value in Container Apps secret store (better than plain env var,
// but still not as strong as centrally managed Key Vault).
// Path 3: no secret created when both inputs are empty.
var secretList = keyVaultSecretUrl != ''
  ? [
      {
        name: 'app-secret'
        keyVaultUrl: keyVaultSecretUrl
        identity: identityReferenceForSecretsAndRegistry
      }
    ]
  : inlineSecretValue != ''
      ? [
          {
            name: 'app-secret'
            value: inlineSecretValue
          }
        ]
      : []

// Registry configuration is only injected when private registry usage is enabled.
// This avoids unnecessary registry auth configuration when using public images.
var registryConfiguration = (deployContainerRegistry && usePrivateRegistry) ? [
  {
    server: containerRegistry!.properties.loginServer
    identity: identityReferenceForSecretsAndRegistry
  }
] : []

// Base environment variables available to the app at runtime.
// Keep non-sensitive variables in `value`.
var appEnvironmentVariablesBase = [
  {
    name: 'APP_ENVIRONMENT'
    value: 'production'
  }
]

// Secret reference environment variable is injected only when a secret exists.
// `secretRef` means app gets value from secure secret store instead of plain-text config.
var appEnvironmentSecretVariable = length(secretList) > 0 ? [
  {
    name: 'APP_SECRET_VALUE'
    secretRef: 'app-secret'
  }
] : []

// Final app environment variable list.
// `concat` keeps template logic clean and avoids duplicating whole env arrays.
var appEnvironmentVariables = concat(appEnvironmentVariablesBase, appEnvironmentSecretVariable)

// ------------------------------
// Core resources
// ------------------------------

// Centralized logging for ACA environment and workloads.
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  // Workspace resource name in Azure.
  name: logAnalyticsWorkspaceName
  // Region where workspace is created.
  location: location
  // Governance tags copied from top-level `tags` parameter.
  tags: tags
  properties: {
    // Cost/performance model for log ingestion and query.
    sku: {
      // PerGB2018 is current common pay-as-you-go workspace SKU.
      name: 'PerGB2018'
    }
    // How long logs are kept by default in interactive retention.
    retentionInDays: 30
    features: {
      // This enforces RBAC-aware access patterns for logs instead of broad workspace permissions.
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Securely read shared key needed by managed environment log pipeline.
// This key lets Container Apps environment write logs into this workspace.
var logAnalyticsSharedKey = logAnalyticsWorkspace.listKeys().primarySharedKey

// Optional dedicated VNet for network isolation and policy control.
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = if (deployVirtualNetwork) {
  // VNet name for private networking boundary.
  name: virtualNetworkName
  // Region for VNet.
  location: location
  // Governance tags.
  tags: tags
  properties: {
    // Top-level VNet address range.
    addressSpace: {
      addressPrefixes: [
        // Supernet that contains the infrastructure subnet.
        '10.42.0.0/16'
      ]
    }
    // Subnet list.
    subnets: [
      {
        // Dedicated subnet name for ACA infrastructure plane.
        name: infrastructureSubnetName
        properties: {
          // CIDR block assigned to this subnet.
          addressPrefix: infrastructureSubnetPrefix
          // Delegation allows Azure Container Apps service to manage required infra inside subnet.
          delegations: [
            {
              name: 'container-apps-delegation'
              properties: {
                // Required delegation target for Container Apps environments.
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
    ]
  }
}

// Create reusable user-assigned identity when enabled.
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (createUserAssignedIdentity) {
  // User-assigned identity resource name.
  name: userAssignedIdentityName
  // Region for identity resource.
  location: location
  // Governance tags.
  tags: tags
}

// Optional private registry with secure defaults.
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-06-01-preview' = if (deployContainerRegistry) {
  // ACR resource name (must be globally unique).
  name: containerRegistryName
  // Region for registry.
  location: location
  // Governance tags.
  tags: tags
  sku: {
    // Premium unlocks advanced enterprise/security/network capabilities.
    name: 'Premium'
  }
  properties: {
    // Disable admin user to prevent long-lived username/password auth.
    adminUserEnabled: false
    // Block anonymous image pulls for security.
    anonymousPullEnabled: false
    // Keep enabled here for learning simplicity; can be disabled with private endpoints in stricter setups.
    publicNetworkAccess: 'Enabled'
    // Allows trusted Azure services where needed while still controlling other behavior.
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      azureADAuthenticationAsArmPolicy: {
        // Enforce Entra-aware ARM auth policy support.
        status: 'enabled'
      }
      exportPolicy: {
        // Disable artifact export to reduce exfiltration risk.
        status: 'disabled'
      }
      retentionPolicy: {
        // Automatically clean untagged manifests after this many days.
        status: 'enabled'
        days: 14
      }
      softDeletePolicy: {
        // Retain deleted artifacts temporarily for recovery.
        status: 'enabled'
        retentionDays: 7
      }
      quarantinePolicy: {
        // Enable quarantine policy for safer artifact workflows.
        status: 'enabled'
      }
      trustPolicy: {
        // Notary setting is shown for learning; left disabled unless your supply-chain flow requires it.
        status: 'disabled'
        type: 'Notary'
      }
    }
    // Increase resiliency where zone redundancy is supported.
    zoneRedundancy: 'Enabled'
  }
}

// Managed environment is the secure boundary for apps + jobs.
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  // Container Apps environment name.
  name: containerAppsEnvironmentName
  // Region for environment.
  location: location
  // Governance tags.
  tags: tags
  properties: union({
    // Spreads platform components across zones when region supports it.
    zoneRedundant: zoneRedundant
    appLogsConfiguration: {
      // Send app/platform logs to Log Analytics.
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        // Workspace customer ID (workspace identifier).
        customerId: logAnalyticsWorkspace.properties.customerId
        // Workspace shared key used by platform pipeline to send logs.
        sharedKey: logAnalyticsSharedKey
      }
    }
    // Optional dedicated/consumption workload profile definitions.
    workloadProfiles: workloadProfiles
  }, deployVirtualNetwork ? {
    vnetConfiguration: {
      // Full subnet resource ID where ACA environment infrastructure is placed.
      infrastructureSubnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, infrastructureSubnetName)
      // `true` means environment endpoint is internal load balancer only.
      internal: internalLoadBalancer
    }
  } : {})
}

// Diagnostic settings ensure platform/resource logs are exported for SOC and incident response.
resource containerAppsEnvironmentDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  // Diagnostic setting resource name.
  name: '${containerAppsEnvironmentName}-diag'
  // Scope is the managed environment resource itself.
  scope: containerAppsEnvironment
  properties: {
    // Destination workspace receiving logs/metrics.
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        // Collect all available log categories for stronger security visibility.
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        // Collect all published metrics for monitoring and alerting.
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Main secure app. Internal ingress and managed identity are secure defaults.
resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  // Container app name.
  name: containerAppName
  // Region for app.
  location: location
  // Governance tags.
  tags: tags
  // Managed identity is always present (directly or via safety guard) for secure secret/registry integration.
  identity: {
    // Selected identity mode from `appIdentityType` variable.
    type: appIdentityType
    // Map of user-assigned identity IDs when enabled.
    userAssignedIdentities: userAssignedIdentityMap
  }
  properties: {
    // Bind app to the managed environment boundary.
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: union({
      // Single revision mode simplifies operational/security behavior in many SaaS baselines.
      activeRevisionsMode: 'Single'
      // Ingress policy/config assembled in derived vars.
      ingress: ingressConfiguration
      // Keep some inactive revisions for rollback/debug history.
      maxInactiveRevisions: 10
      // Registry credentials via managed identity when configured.
      registries: registryConfiguration
      // Secret definitions (Key Vault reference or inline fallback).
      secrets: secretList
    }, daprConfiguration)
    template: {
      // Human-readable revision suffix.
      revisionSuffix: 'r001'
      containers: [
        {
          // Container logical name in this app.
          name: 'api'
          // OCI image reference for app container.
          image: appImage
          // Runtime env variables (base + optional secret ref).
          env: appEnvironmentVariables
          resources: {
            // CPU request/limit style setting expected by ACA runtime.
            cpu: any(appCpuCores)
            // Memory request/limit style setting expected by ACA runtime.
            memory: appMemory
          }
          probes: [
            {
              // Liveness tells platform when container is unhealthy and should restart.
              type: 'Liveness'
              httpGet: {
                // Path used for health check.
                path: '/'
                // Container port used by health check.
                port: targetPort
              }
              // Delay before first probe after container starts.
              initialDelaySeconds: 10
              // Probe interval in seconds.
              periodSeconds: 15
            }
            {
              // Readiness controls when traffic can be sent to this replica.
              type: 'Readiness'
              httpGet: {
                // Path used for readiness check.
                path: '/'
                // Port used for readiness check.
                port: targetPort
              }
              // Shorter delay so app becomes routable quickly when ready.
              initialDelaySeconds: 5
              // Readiness polling interval.
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        // Minimum warm replicas.
        minReplicas: minReplicas
        // Maximum autoscale replicas.
        maxReplicas: maxReplicas
        rules: [
          // HTTP scale rule: autoscale on concurrent requests.
          {
            name: 'http-scale'
            http: {
              metadata: {
                // Scale threshold for concurrent requests per replica.
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

// Send app diagnostics to Log Analytics for auditing and operations.
resource containerAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  // Diagnostic setting resource name.
  name: '${containerAppName}-diag'
  // Scope is container app resource.
  scope: containerApp
  properties: {
    // Destination workspace.
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        // Capture all app log categories.
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        // Capture all app metrics categories.
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Optional scheduled background worker job for recurring platform tasks.
resource scheduledJob 'Microsoft.App/jobs@2025-01-01' = if (deployScheduledJob) {
  // Job resource name.
  name: jobName
  // Region for job resource.
  location: location
  // Governance tags.
  tags: tags
  identity: {
    // Same identity strategy as app for registry/secret consistency.
    type: appIdentityType
    // User-assigned identity map if enabled.
    userAssignedIdentities: userAssignedIdentityMap
  }
  properties: {
    // Bind job to same Container Apps environment.
    environmentId: containerAppsEnvironment.id
    configuration: {
      // Schedule trigger runs job based on cron expression.
      triggerType: 'Schedule'
      scheduleTriggerConfig: {
        // Cron schedule.
        cronExpression: jobCronExpression
        // Number of parallel job replicas per execution.
        parallelism: 1
        // Required successful replicas before execution considered complete.
        replicaCompletionCount: 1
      }
      // Retry count if execution fails.
      replicaRetryLimit: jobReplicaRetryLimit
      // Timeout per execution in seconds.
      replicaTimeout: jobReplicaTimeout
      // Registry auth config.
      registries: registryConfiguration
      // Secret config.
      secrets: secretList
    }
    template: {
      containers: [
        {
          // Container name for job workload.
          name: 'job'
          // Job image reference.
          image: jobImage
          env: [
            {
              // Example non-secret env for job behavior tagging.
              name: 'JOB_MODE'
              value: 'scheduled-maintenance'
            }
          ]
          resources: {
            // Lightweight CPU for periodic maintenance job.
            cpu: any('0.25')
            // Lightweight memory for periodic maintenance job.
            memory: '0.5Gi'
          }
        }
      ]
    }
  }
}

// Role definition id for AcrPull built-in role.
// This GUID is Microsoft built-in AcrPull role id.
var acrPullRoleDefinitionResourceId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

// Grant ACR pull to system-assigned identity when private registry is used.
resource appSystemAssignedAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployContainerRegistry && usePrivateRegistry && safeSystemAssignedIdentity) {
  // Deterministic guid avoids duplicate role assignment errors across reruns.
  name: guid(containerRegistry!.id, containerApp.id, acrPullRoleDefinitionResourceId, 'system-assigned-acrpull')
  // Role is granted at ACR scope.
  scope: containerRegistry!
  properties: {
    // Role definition being granted.
    roleDefinitionId: acrPullRoleDefinitionResourceId
    // Principal is app system-assigned managed identity.
    principalId: containerApp.identity.principalId
    // Principal type expected for managed identities.
    principalType: 'ServicePrincipal'
  }
}

// Grant ACR pull to user-assigned identity when enabled.
resource userAssignedIdentityAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployContainerRegistry && usePrivateRegistry && createUserAssignedIdentity) {
  // Deterministic guid for user-assigned identity grant.
  name: guid(containerRegistry!.id, userAssignedIdentity!.id, acrPullRoleDefinitionResourceId, 'user-assigned-acrpull')
  // Role is granted at ACR scope.
  scope: containerRegistry!
  properties: {
    // Role definition being granted.
    roleDefinitionId: acrPullRoleDefinitionResourceId
    // Principal is user-assigned identity service principal object.
    principalId: userAssignedIdentity!.properties.principalId
    // Principal type expected for managed identities.
    principalType: 'ServicePrincipal'
  }
}

// ------------------------------
// Outputs
// ------------------------------

// Output environment ARM resource ID for scripting and integrations.
output managedEnvironmentId string = containerAppsEnvironment.id
// Output app ARM resource ID for scripting and integrations.
output containerAppResourceId string = containerApp.id
// Output generated ingress FQDN.
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
// Output whether ingress is public internet facing.
output containerAppIngressIsExternal bool = enableExternalIngress
// Output ACR login server hostname when registry is created.
output containerRegistryLoginServer string = deployContainerRegistry ? containerRegistry!.properties.loginServer : 'not-created'
