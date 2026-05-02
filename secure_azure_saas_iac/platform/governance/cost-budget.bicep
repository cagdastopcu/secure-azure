// -----------------------------------------------------------------------------
// FILE: Subscription budget guardrail module.
// USED IN SAAS FLOW: Raises forecast/actual threshold alerts for platform spend.
// SECURITY-CRITICAL: Cost spikes can indicate misuse/compromise and should be investigated quickly.
// -----------------------------------------------------------------------------
// Cost governance baseline budget at subscription scope.
// Why: early cost overrun warning for SaaS platform operations.
targetScope = 'subscription'

@description('Monthly budget amount in subscription currency.')
@minValue(1)
param monthlyBudgetAmount int

@description('Email address that receives budget alerts.')
param budgetAlertEmail string

@description('Budget name.')
param budgetName string = 'saas-platform-monthly-budget'

@description('Budget start date in YYYY-MM-DD format.')
param budgetStartDate string

resource monthlyBudget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: monthlyBudgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      forecasted_80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        thresholdType: 'Forecasted'
        contactEmails: [
          budgetAlertEmail
        ]
      }
      actual_100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: [
          budgetAlertEmail
        ]
      }
    }
  }
}

output budgetResourceId string = monthlyBudget.id
