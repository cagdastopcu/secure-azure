// -----------------------------------------------------------------------------
// FILE: Subscription activity log export module.
// USED IN SAAS FLOW: Sends control-plane events to central workspace for audit timeline.
// SECURITY-CRITICAL: Preserves forensic evidence for incident response and compliance.
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
