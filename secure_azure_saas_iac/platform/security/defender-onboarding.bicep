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
// - SaaS use here: Enables Defender security plans to improve SaaS threat detection and posture.
// -----------------------------------------------------------------------------

// Defender for Cloud onboarding at subscription scope.
// Why: baseline posture management and threat protection plans.
targetScope = 'subscription'

@description('Defender plans to enable at subscription scope.')
param defenderPlanNames array = [
  'VirtualMachines'
  'StorageAccounts'
  'KeyVaults'
  'Containers'
]

resource defenderPlans 'Microsoft.Security/pricings@2023-01-01' = [for planName in defenderPlanNames: {
  name: planName
  properties: {
    pricingTier: 'Standard'
  }
}]

// Return declared plan names directly to avoid collection-reference limitations at output time.
output enabledPlans array = defenderPlanNames
