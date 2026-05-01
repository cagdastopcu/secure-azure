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
// - SaaS use here: Exports subscription activity logs for SaaS forensics and compliance.
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
