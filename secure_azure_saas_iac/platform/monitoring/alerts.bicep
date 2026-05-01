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
var monitoredScope = '/subscriptions/${subscriptionId}'

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
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
