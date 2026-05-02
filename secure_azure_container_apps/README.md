# Secure Azure Container Apps Learning Blueprint

This folder contains a security-focused Azure Container Apps infrastructure template and a PowerShell test runner.

It is designed for two goals:
- Learn how Azure Container Apps building blocks fit together.
- Deploy a strong baseline with secure defaults you can extend for SaaS workloads.

## Folder Contents

- `main.bicep`: Main Infrastructure-as-Code template.
- `main.json`: Compiled ARM JSON output from `main.bicep`.
- `test-secure-aca.ps1`: Test/deploy script for compile, validate, what-if, optional deploy, and security smoke checks.

## What `main.bicep` Deploys

`main.bicep` is a full resource-group scope deployment (`targetScope = 'resourceGroup'`) with optional components controlled by parameters.

Core resources:
- Log Analytics Workspace
- Optional Virtual Network + delegated infrastructure subnet
- Container Apps Environment
- Optional User-Assigned Managed Identity
- Optional Azure Container Registry (ACR)
- Main Container App (API-style service)
- Optional Container Apps Job (scheduled background worker)
- Diagnostic settings for environment and app
- Optional ACR role assignments (`AcrPull`) for managed identities

## Architecture Flow (How Components Connect)

1. Log Analytics is created first for centralized logs.
2. Optional VNet/subnet is created and delegated to `Microsoft.App/environments`.
3. Container Apps Environment is created and connected to Log Analytics.
4. Main Container App is deployed into that environment.
5. Optional scheduled job is deployed into the same environment.
6. Optional ACR is created and app identity is granted pull role.
7. Diagnostics stream logs/metrics into Log Analytics.

## Security Baseline in the Template

The template is intentionally opinionated toward secure defaults:
- Internal ingress by default (`enableExternalIngress = false`).
- HTTP insecure traffic disabled (`allowInsecure = false`).
- Managed identity is always enforced through `safeSystemAssignedIdentity` guard.
- Secret handling prefers Key Vault reference over inline value.
- ACR admin user disabled.
- ACR anonymous pull disabled.
- Environment and app diagnostics enabled.
- `AcrPull` role assignment uses scoped RBAC at registry scope.
- Optional VNet + internal load balancer mode for stronger network isolation.

## Parameter Model in `main.bicep`

The file uses parameters grouped by concern.

General:
- `location`: deployment region.
- `prefix`: naming prefix for resources.
- `tags`: governance tags.

Observability:
- `logAnalyticsWorkspaceName`

Networking/Environment:
- `containerAppsEnvironmentName`
- `deployVirtualNetwork`
- `virtualNetworkName`
- `infrastructureSubnetName`
- `infrastructureSubnetPrefix`
- `internalLoadBalancer`
- `zoneRedundant`
- `workloadProfiles`

Identity/Registry:
- `createUserAssignedIdentity`
- `userAssignedIdentityName`
- `useSystemAssignedIdentity`
- `deployContainerRegistry`
- `containerRegistryName`
- `usePrivateRegistry`
- `appImage`

Primary app:
- `containerAppName`
- `enableExternalIngress`
- `targetPort`
- `minReplicas`
- `maxReplicas`
- `appCpuCores`
- `appMemory`
- `enableDapr`
- `daprAppId`
- `ipSecurityRestrictions`
- `keyVaultSecretUrl`
- `inlineSecretValue` (secure parameter)

Scheduled job:
- `deployScheduledJob`
- `jobName`
- `jobImage`
- `jobCronExpression`
- `jobReplicaRetryLimit`
- `jobReplicaTimeout`

## Important Derived Variables (Why They Exist)

- `safeSystemAssignedIdentity`: prevents “no identity” deployments that would break secure secret/registry auth.
- `appIdentityType`: computes exact identity mode string expected by ARM.
- `userAssignedIdentityMap`: creates required ARM map structure for UAMI.
- `identityReferenceForSecretsAndRegistry`: chooses UAMI ID or `system` identity reference.
- `ingressConfiguration`: central place for ingress policy.
- `daprConfiguration`: conditionally injects Dapr config.
- `secretList`: switches between Key Vault reference, inline secret, or no secret.
- `registryConfiguration`: injects registry auth only when needed.
- `appEnvironmentVariables`: builds final app env var list without duplication.

## Secret Strategy

Priority order:
1. If `keyVaultSecretUrl` is provided, the app secret is configured as Key Vault reference.
2. Else, if `inlineSecretValue` is provided, it is stored as Container App secret.
3. Else, no secret is created.

Operational recommendation:
- Use Key Vault URI (prefer versionless URI) with managed identity in real environments.
- Keep `inlineSecretValue` empty outside lab/demo use.

## Networking and Exposure Model

- Default mode is private/internal service pattern.
- `enableExternalIngress = false` means no public app endpoint exposure.
- `internalLoadBalancer = true` with VNet mode limits environment edge to internal load balancing.
- `ipSecurityRestrictions` can add CIDR allow/deny control on ingress.

Typical SaaS edge pattern:
- Keep container app internal.
- Place external edge service (Front Door, APIM, WAF-enabled ingress) in front when public access is required.

## Autoscaling and Health

Main app scaling:
- `minReplicas` and `maxReplicas` control baseline and burst capacity.
- HTTP scale rule uses `concurrentRequests: '50'`.

Health probes:
- Liveness probe for restart decision.
- Readiness probe for traffic eligibility decision.

Why this matters:
- Better uptime and safer rollouts under load.

## Container Registry Hardening in This Template

When `deployContainerRegistry = true`:
- Premium SKU
- `adminUserEnabled = false`
- `anonymousPullEnabled = false`
- export policy disabled
- retention + soft delete + quarantine policy enabled
- optional zone redundancy

Role assignments:
- System-assigned MI and/or UAMI get `AcrPull` at registry scope when private registry mode is enabled.

## Diagnostics and SOC Visibility

Two diagnostic settings are deployed:
- Environment diagnostics to Log Analytics
- Container App diagnostics to Log Analytics

Both enable:
- `allLogs`
- `AllMetrics`

This gives baseline telemetry for:
- incident triage
- change impact analysis
- security monitoring

## Outputs from `main.bicep`

- `managedEnvironmentId`
- `containerAppResourceId`
- `containerAppFqdn`
- `containerAppIngressIsExternal`
- `containerRegistryLoginServer`

Use outputs for:
- CI/CD handoff
- post-deploy validation
- integration scripts

## How `test-secure-aca.ps1` Works

The script is a safe test runner with optional deployment.

High-level flow:
1. Resolve Azure CLI path (`Find-AzCli`).
2. Validate template file exists.
3. Optionally switch subscription.
4. Ensure target resource group exists (create if missing).
5. Compile Bicep (`az bicep build`).
6. ARM validate (`az deployment group validate`).
7. What-if preview (`az deployment group what-if`).
8. If `-Deploy` is set, run real deployment.
9. Run security smoke checks against deployed app.

Security smoke checks verify:
- `ingress.allowInsecure` is `false`
- `activeRevisionsMode` is `Single`
- managed identity is present

Helper functions:
- `Run-Az`: execute command and enforce exit-code handling.
- `Run-AzJson`: execute command + parse JSON safely.

Why helpers matter:
- reliable failure handling
- cleaner script
- less duplicated error logic

## How to Run

Non-destructive test:

```powershell
.\secure_azure_container_apps\test-secure-aca.ps1 `
  -ResourceGroupName rg-aca-learn `
  -Location westeurope `
  -Prefix acalearn
```

Deploy and run smoke checks:

```powershell
.\secure_azure_container_apps\test-secure-aca.ps1 `
  -ResourceGroupName rg-aca-learn `
  -Location westeurope `
  -Prefix acalearn `
  -Deploy
```

Deploy with private registry and external ingress toggles:

```powershell
.\secure_azure_container_apps\test-secure-aca.ps1 `
  -ResourceGroupName rg-aca-learn `
  -Prefix acalearn `
  -UsePrivateRegistry `
  -EnableExternalIngress `
  -Deploy
```

## Safe Learning Sequence (Recommended)

1. Run non-destructive test first (build + validate + what-if).
2. Review what-if output.
3. Deploy into a dedicated dev/test resource group.
4. Inspect generated resources and diagnostics in Azure Portal.
5. Add Key Vault secret reference and test again.
6. Move to stricter network patterns (private endpoints, edge-only exposure) for production.

## Production Hardening Next Steps

- Replace public ingress with private edge pattern (Front Door/APIM/WAF + private backend).
- Use private endpoints for data services and registry where required.
- Use Azure Policy for guardrails (deny public exposure, require diagnostics, require tags).
- Add CI gates for `what-if` and policy compliance.
- Add Defender for Cloud and Sentinel analytics rules.
- Rotate secrets and move all secrets to Key Vault references.

## Notes About `main.json`

`main.json` is generated output from Bicep compile.
- Do not manually edit `main.json` as primary source of truth.
- Treat `main.bicep` as canonical IaC and regenerate JSON when needed.

## Official References Used for Design

- Azure Container Apps ingress, identity, jobs, networking, and template references on Microsoft Learn.
- Azure CLI deployment `validate` and `what-if` command references on Microsoft Learn.
- Log Analytics workspace access-mode guidance on Microsoft Learn.
