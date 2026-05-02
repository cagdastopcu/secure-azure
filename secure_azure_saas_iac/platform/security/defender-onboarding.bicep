// -----------------------------------------------------------------------------
// FILE: Defender for Cloud plan onboarding module.
// USED IN SAAS FLOW: Enables selected security plans during platform bootstrap.
// SECURITY-CRITICAL: Expands threat detection and posture insights across subscription assets.
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
