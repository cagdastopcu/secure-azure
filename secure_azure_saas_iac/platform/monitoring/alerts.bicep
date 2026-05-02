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
//   1. Creates baseline alert routing and activity-log alerts.
//   2. Used by SOC/ops to detect control-plane and policy issues.
//   3. Inputs: subscription scope and email destination.
//   4. Outputs: action group ID for future alert chaining.
//   5. Security role: improves detection speed and alert consistency.
// -----------------------------------------------------------------------------
// Baseline alert routing module.
// Why: sends important platform events to an operator mailbox.
targetScope = 'resourceGroup'

@description('Deployment location for action group metadata.')
param location string

@description('Project prefix for naming alert resources.')
param projectPrefix string

@description('Environment label for naming alert resources.')
param environment string

@description('Subscription ID monitored by activity log alerts.')
param subscriptionId string = subscription().subscriptionId

@description('Email address for alert notifications.')
param alertEmail string

@description('Tags to apply.')
param tags object = {}

var actionGroupName = '${projectPrefix}-${environment}-ag'
var adminAlertName = '${projectPrefix}-${environment}-admin-errors'
var policyAlertName = '${projectPrefix}-${environment}-policy-deny'
// Activity Log alerts must scope to a subscription/resource group path.
var monitoredScope = '/subscriptions/${subscriptionId}'

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  // Azure Monitor action groups are global resources even if deployment is RG-scoped.
  location: 'global'
  tags: tags
  properties: {
    groupShortName: take(replace('${projectPrefix}${environment}ag', '-', ''), 12)
    enabled: true
    emailReceivers: [
      {
        name: 'platform-email'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource adminErrorAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: adminAlertName
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    scopes: [
      monitoredScope
    ]
    condition: {
      allOf: [
        {
          // Administrative + Error catches failing control-plane operations quickly.
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'level'
          equals: 'Error'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

resource policyDenyAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: policyAlertName
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    scopes: [
      monitoredScope
    ]
    condition: {
      allOf: [
        {
          // Policy category indicates denied/non-compliant operations and governance drift attempts.
          field: 'category'
          equals: 'Policy'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

output actionGroupId string = actionGroup.id
