# Secure Azure SaaS IaC

Enterprise-style, security-first Infrastructure as Code baseline for Azure SaaS platforms.

This folder contains a modular Bicep implementation that deploys:
- Platform baseline (network, monitoring, governance policy)
- Secure runtime stamp (Azure Container Apps + Key Vault + private networking)
- CI validation workflow with OIDC and what-if controls

## 1. Why This Exists

Most SaaS teams need two things at the same time:
- Speed to deliver features
- Strong security and governance defaults

This IaC baseline is designed to avoid insecure “temporary” shortcuts by making secure choices the default behavior.

## 2. Design Principles

- Secure by default: no public Key Vault endpoint, internal-first app exposure
- Least privilege: managed identities and scoped RBAC roles
- Policy-driven governance: enforce location and tagging rules
- Repeatability: deterministic naming and module composition
- Operational visibility: centralized logs and app telemetry
- Progressive hardening: easy path from startup baseline to enterprise controls

## 3. What Gets Deployed

## 3.1 Platform Modules
- `platform/network/main.bicep`
  - VNet
  - ACA infrastructure subnet (delegated)
  - Private endpoint subnet
- `platform/monitoring/main.bicep`
  - Log Analytics workspace
  - Workspace-based Application Insights
- `platform/policy/security-baseline.bicep`
  - Allowed locations policy assignment
  - Required tag/value policy assignments

## 3.2 Workload Stamp
- `stamps/aca-stamp/main.bicep`
  - Azure Container Apps managed environment
  - Key Vault with:
    - RBAC authorization
    - soft delete + purge protection
    - `publicNetworkAccess: Disabled`
  - User-assigned managed identities (web/worker)
  - Key Vault role assignments (`Key Vault Secrets User`)
  - Web container app (public ingress opt-in)
  - Worker container app (internal-only)
  - Key Vault private endpoint
  - Private DNS zone + VNet link + DNS zone group

## 3.3 Root Orchestrator
- `main.bicep`
  - Wires modules and passes dependencies via outputs
  - Exposes safe operational outputs

## 4. Current Security Posture

Implemented now:
- `enablePublicWebIngress=false` by default
- TLS-only ingress behavior (`allowInsecure: false`)
- Key Vault private-only network path
- Managed identity auth for workloads
- Least-privilege role assignment to Key Vault
- Region and tag governance policies
- CI hardening controls:
  - OIDC login
  - minimal token permissions
  - concurrency control
  - timeout
  - strict shell mode (`set -euo pipefail`)
  - checkout token not persisted

## 5. Repository Structure

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

## 6. Parameters You Will Use Most

From `main.bicep`:
- `location`: target Azure region
- `environment`: `dev|test|prod`
- `projectPrefix`: naming prefix
- `vnetAddressPrefix`, `acaInfraSubnetPrefix`, `privateEndpointSubnetPrefix`
- `logRetentionInDays`
- `bootstrapContainerImage`
- `enablePublicWebIngress`
- `allowedIngressCidrs`

Recommended production pattern:
- Keep `enablePublicWebIngress=false` unless intentionally publishing internet endpoints
- If `true`, set `allowedIngressCidrs` to strict trusted ranges only

## 7. Deployment Flow

1. Deploy `main.bicep` to a resource group.
2. Monitoring/network/policy baseline deploy first.
3. ACA stamp deploys using module outputs.
4. Retrieve outputs (environment name, FQDN, workspace name).

## 8. Quick Start

```bash
az group create --name rg-saas-dev-platform --location westeurope

az deployment group create \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

Validate before apply:

```bash
az deployment group validate \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas

az deployment group what-if \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

## 9. CI/CD Workflow Notes

Executable workflow file:
- `.github/workflows/iac-deploy.yml`

Template/source copy (kept in IaC folder):
- `pipelines/github-actions-iac.yml`

What it does:
- Authenticates to Azure via OIDC (`azure/login`)
- Ensures target RG exists
- Runs Bicep validation
- Runs what-if preview
- Runs on pull requests to `main` and `master`

Why it matters:
- Catches failures/drift before production deployment
- Removes dependency on long-lived cloud secrets

## 10. Threat Model (Practical)

Primary risks addressed:
- Accidental public exposure of app or secrets
- Secret leakage from static credentials
- DNS misconfiguration breaking private endpoint guarantees
- Governance drift from manual changes
- Risky CI behavior (overlapping runs, silent failures)

Controls mapped:
- Private endpoint + private DNS + public access disabled (Key Vault)
- Managed identities + RBAC
- Policy assignments
- CI timeout/concurrency + strict shell mode

## 11. Troubleshooting Guide

- Deployment fails on ACA environment:
  - Check subnet delegation and CIDR size
- Key Vault access fails from app:
  - Verify identity assignment and Key Vault role assignment
  - Verify private endpoint + DNS zone + VNet link
- App ingress not reachable:
  - Confirm `enablePublicWebIngress` setting and `allowedIngressCidrs`
- Policy assignment errors:
  - Verify deployment permissions at RG scope

## 12. Extending This Baseline Safely

When adding SQL/Storage/Redis/Service Bus modules:
- Prefer private endpoints
- Disable public access where supported
- Add diagnostics to Log Analytics
- Use managed identity-based auth
- Extend policy modules for service-specific deny rules

## 13. Hardening Backlog (Recommended Next)

1. Pin GitHub actions to full commit SHAs
2. Add CODEOWNERS for IaC and workflows
3. Enforce branch protection and required checks
4. Add Defender for Cloud onboarding as code
5. Add diagnostic-settings policy enforcement
6. Add environment-specific `.bicepparam` files (dev/test/prod)

## 14. Related Docs

- `docs/DEPLOYMENT.md`
- `docs/LINE_BY_LINE_EXPLANATION.md`
- `docs/SECURITY_AUDIT.md`
- `docs/SECURITY_AUDIT_DEEP.md`

## 15. Disclaimer

This is a strong baseline, not a complete enterprise landing zone.
Treat it as a secure starting point and extend with your org's compliance, identity, and operational standards.
