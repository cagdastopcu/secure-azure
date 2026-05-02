# How To Build a SaaS Project From Zero With This IaC

This guide explains how to build a secure SaaS platform from zero using the IaC in this repository.
It is written for practical execution: what to do, why you do it, and how the Azure parts work together.

---

## 1. What "From Zero" Means

From zero means:
- You have an Azure subscription (or a few subscriptions), but no mature platform yet.
- You want to ship a SaaS product and avoid insecure shortcuts.
- You want one repeatable infrastructure baseline that teams can deploy safely.

This IaC gives you:
- Platform baseline (network, monitoring, policy/governance)
- Runtime baseline (Container Apps + Key Vault + managed identities)
- Data baseline (Storage, Service Bus, optional SQL/Redis/Event Grid + private endpoints)
- Optional advanced controls (Firewall egress, APIM, Front Door/WAF, Defender onboarding)

---

## 2. Architecture Strategy Before Writing App Code

### 2.1 Choose your tenant isolation model

Pick the tenancy model up front because it affects networking, data, and cost:
- Shared app + shared data (lowest cost, highest carefulness needed)
- Shared app + database-per-tenant (balanced)
- Dedicated stamp per tenant (strong isolation, highest cost/ops)

Use your SaaS tiering to migrate customers between models over time.

### 2.2 Define environments and blast-radius boundaries

Minimum:
- `dev`
- `test`
- `prod`

Best practice:
- Separate subscriptions for each environment (especially prod) to reduce risk.
- Keep platform guardrails centralized using policy.

### 2.3 Define reliability targets

Set:
- RTO (Recovery Time Objective)
- RPO (Recovery Point Objective)

Then configure:
- SQL backup retention
- SQL backup redundancy mode
- DR runbook drills

---

## 3. Map This Repository to Azure Building Blocks

`main.bicep` orchestrates everything.

### 3.1 Platform modules

- `platform/network/main.bicep`
  - VNet + ACA delegated subnet + private endpoint subnet
  - Optional DDoS plan
  - Optional private-endpoint subnet NSG
  - Optional Azure Firewall egress path (forced route)

- `platform/monitoring/main.bicep`
  - Log Analytics workspace
  - Application Insights

- `platform/policy/security-baseline.bicep`
  - Region/tag governance assignments

- `platform/policy/public-network-deny.bicep` (optional)
  - Stronger deny-by-policy controls for public network paths

- `platform/security/defender-onboarding.bicep` (optional)
  - Defender for Cloud plan enablement at subscription scope

### 3.2 Stamps

- `stamps/aca-stamp/main.bicep`
  - Container Apps environment
  - Web + worker foundations
  - Key Vault private endpoint and private DNS integration
  - User-assigned identities

- `stamps/data-stamp/main.bicep`
  - Storage + Service Bus baseline
  - Optional SQL/Redis/Event Grid
  - Private endpoints + private DNS zones and links
  - SQL backup resilience controls:
    - short-term retention
    - long-term retention
    - requested backup redundancy

### 3.3 Workload modules

- `workloads/services/api-service.bicep`
- `workloads/services/tenant-onboarding.bicep`
- `workloads/services/jobs/queue-processor.bicep`

These let you add product services without rebuilding the platform baseline.

---

## 4. Step-by-Step Build Plan

## Step 0: Prerequisites

Install:
- Azure CLI
- Bicep support (`az bicep install`)
- PowerShell (for local test scripts)

Sign in:
```bash
az login
az account set --subscription "<subscription-id>"
```

## Step 1: Build your landing zone skeleton

Do this first:
- Management group hierarchy
- Subscription strategy (platform vs workload vs prod separation)
- RBAC model (least privilege, break-glass, approvers)

Why:
- If you skip this, SaaS growth creates governance debt that is expensive to fix later.

## Step 2: Create deployment resource group

```bash
az group create --name rg-saas-dev-platform --location westeurope
```

This group is your first deployment target while iterating.

## Step 3: Validate IaC before first deployment

Run:
```powershell
pwsh -File .\secure_azure_saas_iac\tests\scripts\validate-iac.ps1 -IaCRoot .\secure_azure_saas_iac
pwsh -File .\secure_azure_saas_iac\tests\scripts\assert-security.ps1 -IaCRoot .\secure_azure_saas_iac
```

Why:
- `validate-iac`: catches compile/type/module issues.
- `assert-security`: checks baseline controls are still present.

## Step 4: Preview changes with what-if

```bash
az deployment group what-if \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

Why:
- Prevents surprise creations/updates/deletes.
- Required habit before production.

## Step 5: Deploy baseline

```bash
az deployment group create \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

## Step 6: Validate deployed controls

Check that:
- Web public ingress default is still off unless explicitly enabled.
- Key Vault has public network disabled.
- Private endpoints exist for configured data services.
- Log Analytics is receiving data.

## Step 7: Add your first product workload

Use `workloads/services/api-service.bicep` and deploy your API container with:
- managed identity
- internal or restricted ingress
- Key Vault URI environment variable

Then add background processing with `jobs/queue-processor.bicep` if event-driven behavior is needed.

## Step 8: Turn on advanced controls based on maturity

Recommended production sequence:
1. `deployDefenderOnboarding = true`
2. `deployResourceDiagnostics = true`
3. `deployPlatformAlerts = true`
4. `deployAdvancedPublicNetworkDenyPolicies = true`
5. `enableAzureFirewallForEgress = true` (for stricter egress governance)
6. `deployApiManagement = true` (when API lifecycle/governance requirements grow)
7. `deployEdgeFrontDoor = true` with WAF for public internet edge

## Step 9: Harden data resilience

For SQL:
- `sqlShortTermRetentionDays`
- `enableSqlLongTermRetention`
- `sqlLongTerm*Retention`
- `sqlBackupStorageRedundancy`

For Storage:
- choose redundancy SKU aligned to DR plan (`Standard_GRS` default in root parameters)

## Step 10: Operationalize DR

Use:
- `docs/DR_RESTORE_FAILOVER_RUNBOOK.md`
- SOC playbooks under `docs/soc_playbooks/`

Run drills:
- Quarterly tabletop
- Periodic live restore in non-prod

---

## 5. Security-First Defaults in This IaC (And Why They Matter)

- `enablePublicWebIngress = false`
  - prevents accidental internet exposure during early development.

- Key Vault private endpoint + DNS + `publicNetworkAccess: Disabled`
  - ensures secret access path stays private.

- Managed identity pattern
  - avoids hard-coded credentials in app config and pipelines.

- Optional Firewall inspected egress
  - central outbound path control and future rule governance.

- Policy assignments for location/tags
  - enforces governance consistency at scale.

- SQL backup retention and redundancy controls
  - enables practical recovery windows after data incidents.

---

## 6. CI/CD Build Path (Recommended)

Use GitHub Actions with OIDC:
- No long-lived cloud credentials in repo secrets.
- Short-lived tokens issued per workflow run.

Pipeline stages:
1. Static checks (`validate-iac`, `assert-security`)
2. `what-if`
3. Deploy to non-prod
4. Smoke tests
5. Manual approval
6. Deploy to prod

Add protections:
- branch protection
- required checks
- environment approvals
- CODEOWNERS for IaC paths

---

## 7. Go-Live Checklist

- Environments separated (`dev/test/prod`)
- Role model reviewed (least privilege + emergency access)
- Public ingress minimized and IP-restricted
- Policy compliance acceptable
- Defender recommendations triaged
- Backup/restore tests completed
- Incident and communication runbooks reviewed
- Monitoring dashboards and alerts tuned
- Budget alerts configured

---

## 8. Common Mistakes To Avoid

- Treating `what-if` as optional
- Enabling public ingress early "just for testing"
- Using connection strings/secrets instead of managed identity
- Skipping private DNS when private endpoints are added
- No restore drills even though backups exist
- Mixing platform and workload ownership with no clear boundaries

---

## 9. Suggested 90-Day Execution Plan

### Days 1-15
- Stand up landing zone basics
- Deploy this baseline in dev
- Validate pipeline and checks

### Days 16-30
- Deploy first API + worker workloads
- Wire identity and Key Vault
- Add alerts and diagnostics

### Days 31-60
- Add SQL/Redis/Event Grid as needed
- Finalize data backup strategy and retention values
- Start SOC runbook onboarding

### Days 61-90
- Enable stronger policy/defender controls
- Enable Firewall/APIM/Front Door based on readiness
- Run DR and incident exercises before production freeze

---

## 10. Official Guidance and Reference Implementations

### Microsoft Learn (official)
- Azure Well-Architected Framework:
  - https://learn.microsoft.com/en-us/azure/well-architected/
- Azure Well-Architected SaaS workloads:
  - https://learn.microsoft.com/en-us/azure/well-architected/saas/get-started
- Cloud Adoption Framework landing zone design principles:
  - https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-principles
- Bicep + GitHub Actions quickstart:
  - https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-github-actions
- Deployment stacks with Bicep:
  - https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks
- Container Apps architecture best practices:
  - https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-container-apps
- Container Apps ingress:
  - https://learn.microsoft.com/azure/container-apps/ingress-overview
- Container Apps managed identity:
  - https://learn.microsoft.com/en-us/azure/container-apps/managed-identity
- Container Apps jobs:
  - https://learn.microsoft.com/en-us/azure/container-apps/jobs
- Key Vault security:
  - https://learn.microsoft.com/en-us/azure/key-vault/general/secure-key-vault
- Private endpoint DNS:
  - https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns
- Azure Policy overview:
  - https://learn.microsoft.com/en-us/azure/governance/policy/overview
- Azure Policy definition structure:
  - https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-basics
- Front Door best practices:
  - https://learn.microsoft.com/en-us/azure/frontdoor/best-practices
- Front Door WAF best practices:
  - https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/waf-front-door-best-practices
- API Management private endpoint:
  - https://learn.microsoft.com/en-us/azure/api-management/private-endpoint
- Log Analytics workspace overview:
  - https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview
- Activity log export guidance:
  - https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/rest-activity-log
- Budgets tutorial:
  - https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets
- SQL long-term retention:
  - https://learn.microsoft.com/en-us/azure/azure-sql/database/long-term-retention-overview?view=azuresql
- SQL backup settings (including redundancy):
  - https://learn.microsoft.com/en-us/azure/azure-sql/database/automated-backups-change-settings?tabs=powershell&view=azuresql

### GitHub reference code (official Microsoft orgs)
- Azure Quickstart Templates:
  - https://github.com/Azure/azure-quickstart-templates
- Azure Bicep language repo:
  - https://github.com/Azure/bicep
- Azure Verified Modules catalog:
  - https://azure.github.io/Azure-Verified-Modules/indexes/bicep/bicep-resource-modules/
- GitHub OIDC with Azure:
  - https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure

---

If you want, the next step is to create a second file: a concrete "Day 1 execution checklist" with exact commands and parameter values for your `dev`, `test`, and `prod` environments.
