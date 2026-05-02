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
//   1. Exports subscription activity logs to central analytics.
//   2. Used to maintain audit trail for admin and policy actions.
//   3. Inputs: destination workspace ID and enable switch.
//   4. Outputs: diagnostic setting name.
//   5. Security role: preserves evidence for incident timelines.
// -----------------------------------------------------------------------------
// Subscription activity log export.
// Why: central audit trail of control-plane operations for incident response/compliance.
targetScope = 'subscription'

@description('Log Analytics workspace resource ID destination.')
param logAnalyticsWorkspaceId string

@description('Enable activity log diagnostic export.')
param enableActivityLogExport bool = true

resource subscriptionActivityLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableActivityLogExport) {
  scope: subscription()
  name: 'subscription-activitylog-to-law'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'Administrative'
        enabled: true
      }
      {
        category: 'Security'
        enabled: true
      }
      {
        category: 'Policy'
        enabled: true
      }
      {
        category: 'Alert'
        enabled: true
      }
      {
        category: 'Recommendation'
        enabled: true
      }
      {
        category: 'ServiceHealth'
        enabled: true
      }
      {
        category: 'ResourceHealth'
        enabled: true
      }
      {
        category: 'Autoscale'
        enabled: true
      }
    ]
  }
}

output activityLogDiagnosticSettingName string = enableActivityLogExport ? subscriptionActivityLogs.name : ''
