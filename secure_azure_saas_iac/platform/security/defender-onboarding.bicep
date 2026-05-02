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
//   1. Enables selected Defender plans at subscription scope.
//   2. Used to bootstrap managed cloud threat detection.
//   3. Inputs: list of Defender plan names.
//   4. Outputs: plan names enabled by deployment.
//   5. Security role: strengthens posture management and threat visibility.
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
