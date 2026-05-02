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
//   1. Creates monthly budget with threshold alerts.
//   2. Used to keep SaaS spend predictable and detectable.
//   3. Inputs: monthly amount, start date, alert email.
//   4. Outputs: budget resource ID.
//   5. Security role: budget anomalies can signal misuse/compromise.
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
