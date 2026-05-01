# KQL Starter Queries for SOC Playbooks

Use these as starting points and adapt field names/workspace schemas as needed.

## 1. Azure Activity Log: Privileged/RBAC Changes
```kql
AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue has_any ("Microsoft.Authorization/roleAssignments/write", "Microsoft.Authorization/roleAssignments/delete")
| project TimeGenerated, Caller, OperationNameValue, ActivityStatusValue, ResourceGroup, ResourceId
| order by TimeGenerated desc
```

## 2. Key Vault Secret Access Spikes
```kql
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName has "SecretGet"
| summarize SecretGetCount = count() by bin(TimeGenerated, 15m), identity_claim_appid_g, Resource
| order by TimeGenerated desc
```

## 3. Container App Revision/Config Changes (Control Plane)
```kql
AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue has "Microsoft.App/containerApps/write"
| project TimeGenerated, Caller, ActivityStatusValue, ResourceId, CorrelationId
| order by TimeGenerated desc
```

## 4. SQL Data Access Burst (Diagnostics)
```kql
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where ResourceProvider == "MICROSOFT.SQL"
| summarize Count=count() by bin(TimeGenerated, 5m), Resource, client_ip_s, database_name_s
| order by TimeGenerated desc
```

## 5. Public Exposure Drift Events
```kql
AzureActivity
| where TimeGenerated > ago(7d)
| where OperationNameValue has_any (
  "Microsoft.Storage/storageAccounts/write",
  "Microsoft.KeyVault/vaults/write",
  "Microsoft.Sql/servers/write"
)
| project TimeGenerated, Caller, OperationNameValue, ResourceId, Properties
| order by TimeGenerated desc
```
