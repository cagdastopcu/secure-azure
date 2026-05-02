# Day 1 / Day 7 / Day 30 Execution Checklist

This checklist is the practical companion to:
- `docs/HOW_TO_BUILD_A_SAAS_FROM_ZERO_WITH_THIS_IAC.md`

It gives a strict execution plan with commands you can run.

---

## 0. Fill These Values First

Set your baseline variables once and reuse them:

```powershell
$SUBSCRIPTION_DEV   = "<dev-subscription-id>"
$SUBSCRIPTION_TEST  = "<test-subscription-id>"
$SUBSCRIPTION_PROD  = "<prod-subscription-id>"

$LOCATION           = "westeurope"
$PROJECT_PREFIX     = "saas"

$RG_DEV_PLATFORM    = "rg-saas-dev-platform"
$RG_TEST_PLATFORM   = "rg-saas-test-platform"
$RG_PROD_PLATFORM   = "rg-saas-prod-platform"
```

If you only have one subscription now, you can still follow this plan by using one subscription and 3 resource groups.

---

## Day 1: Stand Up Secure Baseline in `dev`

## 1. Verify tools

```powershell
az --version
az bicep version
pwsh --version
```

If Bicep is missing:
```powershell
az bicep install
```

## 2. Authenticate and select dev subscription

```powershell
az login
az account set --subscription $SUBSCRIPTION_DEV
az account show --output table
```

## 3. Create dev platform resource group

```powershell
az group create --name $RG_DEV_PLATFORM --location $LOCATION
```

## 4. Run local IaC quality/security gates

```powershell
pwsh -File .\secure_azure_saas_iac\tests\scripts\validate-iac.ps1 -IaCRoot .\secure_azure_saas_iac
pwsh -File .\secure_azure_saas_iac\tests\scripts\assert-security.ps1 -IaCRoot .\secure_azure_saas_iac
```

## 5. Preview deployment (`what-if`) before create

```powershell
az deployment group what-if `
  --resource-group $RG_DEV_PLATFORM `
  --template-file .\secure_azure_saas_iac\main.bicep `
  --parameters location=$LOCATION environment=dev projectPrefix=$PROJECT_PREFIX
```

## 6. Deploy baseline in dev

```powershell
az deployment group create `
  --resource-group $RG_DEV_PLATFORM `
  --template-file .\secure_azure_saas_iac\main.bicep `
  --parameters location=$LOCATION environment=dev projectPrefix=$PROJECT_PREFIX
```

## 7. Capture outputs

```powershell
az deployment group show `
  --resource-group $RG_DEV_PLATFORM `
  --name (az deployment group list --resource-group $RG_DEV_PLATFORM --query "[0].name" -o tsv) `
  --query properties.outputs
```

## 8. Day-1 acceptance checks

- `validate-iac.ps1` passes.
- `assert-security.ps1` passes.
- Key Vault is private-only.
- Web app is not publicly exposed unless explicitly enabled.
- Log Analytics workspace exists.

---

## Day 7: Add CI/CD + Workload + Non-Prod Promotion Path

## 1. Configure GitHub Actions OIDC

Create federated identity for your repo and configure:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID` (dev first)

Use your existing workflow template under:
- `secure_azure_saas_iac/pipelines/github-actions-iac.yml`

## 2. Enforce pull request gates

Require PR checks at minimum:
- `validate-iac.ps1`
- `assert-security.ps1`
- `what-if` preview

## 3. Deploy first workload module into dev

Deploy service module after platform exists:
- `workloads/services/api-service.bicep`
- `workloads/services/tenant-onboarding.bicep`
- `workloads/services/jobs/queue-processor.bicep`

Recommended order:
1. API service
2. Tenant onboarding service
3. Queue processor job

## 4. Turn on baseline operational visibility

In `main.bicep` deployment parameters for dev:
- `deployResourceDiagnostics=true`
- `deployPlatformAlerts=true`
- `deploySubscriptionActivityLogExport=true`

Run `what-if`, then deploy.

## 5. Create `test` environment

```powershell
az account set --subscription $SUBSCRIPTION_TEST
az group create --name $RG_TEST_PLATFORM --location $LOCATION
```

Then deploy using:
- `environment=test`

```powershell
az deployment group create `
  --resource-group $RG_TEST_PLATFORM `
  --template-file .\secure_azure_saas_iac\main.bicep `
  --parameters location=$LOCATION environment=test projectPrefix=$PROJECT_PREFIX
```

## 6. Day-7 acceptance checks

- Dev and test deployments both succeed from IaC.
- PR pipeline blocks unsafe changes.
- First workload is deployed via modules (not manual portal drift).
- Monitoring and alert routing are operational.

---

## Day 30: Production Hardening and Readiness

## 1. Create `prod` environment

```powershell
az account set --subscription $SUBSCRIPTION_PROD
az group create --name $RG_PROD_PLATFORM --location $LOCATION
```

## 2. Enable production hardening toggles

For prod parameter set, strongly consider:
- `deployDefenderOnboarding=true`
- `deployAdvancedPublicNetworkDenyPolicies=true`
- `deployResourceDiagnostics=true`
- `deployPlatformAlerts=true`
- `deploySubscriptionActivityLogExport=true`
- `enableAzureFirewallForEgress=true` (if egress control required)
- `deployEdgeFrontDoor=true` (for public edge workloads)
- `deployApiManagement=true` (for API governance/multi-team growth)
- `applyCriticalResourceDeleteLocks=true`

## 3. Harden SQL resilience settings (if SQL enabled)

Use explicit values:
- `sqlBackupStorageRedundancy=Geo` or `GeoZone` (by regional requirements)
- `sqlShortTermRetentionDays=35`
- `enableSqlLongTermRetention=true`
- `sqlLongTermWeeklyRetention=P12W`
- `sqlLongTermMonthlyRetention=P12M`
- `sqlLongTermYearlyRetention=P5Y`

## 4. Run production pre-flight checks

```powershell
pwsh -File .\secure_azure_saas_iac\tests\scripts\validate-iac.ps1 -IaCRoot .\secure_azure_saas_iac
pwsh -File .\secure_azure_saas_iac\tests\scripts\assert-security.ps1 -IaCRoot .\secure_azure_saas_iac
```

Then:
```powershell
az deployment group what-if `
  --resource-group $RG_PROD_PLATFORM `
  --template-file .\secure_azure_saas_iac\main.bicep `
  --parameters location=$LOCATION environment=prod projectPrefix=$PROJECT_PREFIX
```

## 5. Deploy prod

```powershell
az deployment group create `
  --resource-group $RG_PROD_PLATFORM `
  --template-file .\secure_azure_saas_iac\main.bicep `
  --parameters location=$LOCATION environment=prod projectPrefix=$PROJECT_PREFIX
```

## 6. Execute DR and SOC readiness

Use:
- `docs/DR_RESTORE_FAILOVER_RUNBOOK.md`
- `docs/soc_playbooks/README.md`

Mandatory exercises before full launch:
- Restore drill (SQL + app validation path)
- Incident simulation (identity compromise or data exfiltration scenario)

## 7. Day-30 acceptance checks

- Prod deployed from IaC only.
- Security gates pass in CI.
- Backup + restore workflow tested.
- Incident response process tested.
- Cost budget alerting configured and verified.

---

## Suggested Parameter Files (Next Improvement)

Create:
- `params/dev.bicepparam`
- `params/test.bicepparam`
- `params/prod.bicepparam`

Why:
- Prevents parameter mistakes between environments.
- Makes PR diffs cleaner and audit-friendly.

---

## Ongoing Weekly/Monthly Cadence

Weekly:
- Review failed alerts and noisy rules.
- Review policy non-compliance drift.
- Review deployment history.

Monthly:
- Cost review vs budget thresholds.
- Defender recommendations remediation review.
- Restore walkthrough validation.

Quarterly:
- DR simulation.
- SOC tabletop exercise.
- Security baseline parameter review.
