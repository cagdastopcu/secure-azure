# Secure Azure SaaS IaC - Deep Guide (From Zero)

This README explains the current implementation from first principles and matches the latest hardened code in this folder.

## 1. Purpose
This folder provides a secure-by-default Azure SaaS Infrastructure as Code foundation using Bicep.

Key goals:
- Security-first defaults
- Repeatable environment provisioning
- Clear separation of platform baseline vs workload stamp
- CI checks before deployment

## 2. Core Concepts (Zero to Practical)
- IaC: infrastructure defined in versioned code, not manual portal steps.
- Bicep: Azure-native declarative language compiled to ARM.
- ARM: Azure control plane deployment engine.
- Resource Group: deployment scope for this solution.
- VNet/Subnet: private network boundaries.
- Managed Identity: secretless workload identity.
- Key Vault: central secrets store.
- Private Endpoint: private IP access to PaaS resource.
- Private DNS Zone: resolves service FQDNs to private endpoint IPs.
- Azure Policy: governance guardrails (allow/deny/compliance).
- OIDC: short-lived CI-to-cloud auth without static cloud secret.
- What-if: deployment preview without applying changes.

## 3. Current Security Posture (Implemented)
- Web ingress is internal-only by default (`enablePublicWebIngress=false`).
- If public ingress is enabled, explicit CIDR allow-list is required.
- ACA ingress uses `allowInsecure: false` (TLS-only edge behavior).
- Key Vault public network access is disabled.
- Key Vault access path uses Private Endpoint + Private DNS zone + VNet link + zone group.
- Managed identities are used by web/worker apps.
- Key Vault access is least-privilege (`Key Vault Secrets User`) per identity.
- Policy baseline enforces allowed locations and required tags.
- CI workflow uses OIDC, timeout, concurrency control, strict shell mode, and non-persisted checkout credentials.

## 4. Structure and Why
```text
secure_azure_saas_iac/
  main.bicep
  README.md
  docs/
    DEPLOYMENT.md
    LINE_BY_LINE_EXPLANATION.md
    SECURITY_AUDIT.md
    SECURITY_AUDIT_DEEP.md
  pipelines/
    github-actions-iac.yml
  platform/
    monitoring/main.bicep
    network/main.bicep
    policy/security-baseline.bicep
  stamps/
    aca-stamp/main.bicep
  workloads/
    services/
```

- `main.bicep`: root orchestrator wiring all modules.
- `platform/*`: shared baseline (network/monitoring/policy).
- `stamps/aca-stamp`: secure runtime stamp.
- `pipelines/*`: CI validation and what-if.
- `docs/*`: operational and security documentation.

## 5. Module Breakdown

## 5.1 `main.bicep`
- Central entrypoint.
- Defines shared parameters and tags.
- Calls modules in dependency-aware order.
- Passes security-relevant defaults (`enablePublicWebIngress=false`).

## 5.2 `platform/network/main.bicep`
- Creates VNet.
- Creates delegated ACA subnet.
- Creates private endpoint subnet.

Why: isolates traffic and enables private service access.

## 5.3 `platform/monitoring/main.bicep`
- Creates Log Analytics workspace.
- Creates workspace-based App Insights.

Why: unified logs and telemetry for operations/security visibility.

## 5.4 `platform/policy/security-baseline.bicep`
- Assigns built-in allowed locations policy.
- Assigns required-tag-and-value policies.

Why: enforces governance and reduces configuration drift.

## 5.5 `stamps/aca-stamp/main.bicep`
- Creates ACA environment.
- Creates Key Vault with public access disabled and recovery protections.
- Creates managed identities and least-privilege role assignments.
- Creates web app and internal worker app.
- Creates Key Vault private endpoint and full private DNS plumbing.

Why: secure runtime slice for SaaS workloads with private secret path.

## 6. CI/CD Security Design
In `pipelines/github-actions-iac.yml`:
- `permissions` minimized (`id-token: write`, `contents: read`).
- `concurrency` enabled to prevent overlapping runs.
- `timeout-minutes` limits runner/token exposure window.
- `actions/checkout` uses `persist-credentials: false`.
- `AZURE_CORE_OUTPUT=none` reduces accidental log leakage.
- `set -euo pipefail` enforces fail-fast shell behavior.
- `validate` + `what-if` provide pre-deploy controls.

## 7. Deployment Basics
```bash
az group create --name rg-saas-dev-platform --location westeurope
az deployment group create \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

For change preview:
```bash
az deployment group what-if \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

## 8. Recommended Next Hardening Steps
1. Pin workflow actions by full commit SHA.
2. Add CODEOWNERS for IaC/workflow paths.
3. Enforce branch protection + required status checks.
4. Expand policy baseline for diagnostics/public-access deny on future data modules.
5. Add Defender for Cloud onboarding module.

## 9. Companion Docs
- `docs/DEPLOYMENT.md`
- `docs/LINE_BY_LINE_EXPLANATION.md`
- `docs/SECURITY_AUDIT.md`
- `docs/SECURITY_AUDIT_DEEP.md`
