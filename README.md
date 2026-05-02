# Secure Azure IaC Repository

This repository contains security-focused Azure Infrastructure as Code built with Bicep.

It now has **two main tracks**:
- A full **SaaS platform blueprint** (`secure_azure_saas_iac/`)
- A focused **Azure Container Apps learning blueprint** (`secure_azure_container_apps/`)

## Repository Structure

```text
secure_azure_saas_iac/          # Full SaaS platform IaC (multi-module, enterprise baseline)
secure_azure_container_apps/    # Focused ACA baseline + test runner
.github/                        # CI/CD workflows
BLUEPRINT.md                    # Root-level blueprint references
AZURE_SAAS_PLATFORM_BLUEPRINT.md
```

## Track 1: Full SaaS Platform IaC

Path: `secure_azure_saas_iac/`

What it includes:
- Platform network, monitoring, governance, policy, and security modules
- Container Apps application stamp and data stamp patterns
- Private networking patterns (including private endpoints and DNS integration)
- Optional API edge and egress-control patterns
- SQL resilience controls (PITR + long-term backup retention + redundancy modes)
- SOC playbooks, DR runbooks, and deep operational documentation
- IaC validation and security assertion scripts

Key entry points:
- `secure_azure_saas_iac/main.bicep`
- `secure_azure_saas_iac/README.md`
- `secure_azure_saas_iac/docs/DEPLOYMENT.md`
- `secure_azure_saas_iac/tests/scripts/validate-iac.ps1`
- `secure_azure_saas_iac/tests/scripts/assert-security.ps1`

## Track 2: Secure Azure Container Apps Learning Blueprint

Path: `secure_azure_container_apps/`

What it includes:
- A single-file secure Container Apps baseline template:
  - `main.bicep`
- Generated ARM JSON:
  - `main.json`
- End-to-end test/deploy runner:
  - `test-secure-aca.ps1`
- Deep guide for architecture, parameters, and usage:
  - `README.md`

Core capabilities in this track:
- Container Apps environment with Log Analytics diagnostics
- Optional VNet/internal-load-balancer mode
- Managed identity-first model
- Optional hardened ACR + `AcrPull` role assignments
- Main app + optional scheduled background job
- Secure defaults (internal ingress, no insecure HTTP, diagnostics enabled)

## Quick Start

### A) Deploy Full SaaS Platform Track

```bash
az group create --name rg-saas-dev-platform --location westeurope

az deployment group create \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

### B) Test/Deploy Container Apps Track

Non-destructive test (build + validate + what-if):

```powershell
.\secure_azure_container_apps\test-secure-aca.ps1 `
  -ResourceGroupName rg-aca-learn `
  -Location westeurope `
  -Prefix acalearn
```

Deploy and run security smoke checks:

```powershell
.\secure_azure_container_apps\test-secure-aca.ps1 `
  -ResourceGroupName rg-aca-learn `
  -Location westeurope `
  -Prefix acalearn `
  -Deploy
```

## Documentation Map

SaaS platform documentation:
- `secure_azure_saas_iac/README.md`
- `secure_azure_saas_iac/docs/DEPLOYMENT.md`
- `secure_azure_saas_iac/docs/SECURITY_AUDIT.md`
- `secure_azure_saas_iac/docs/SECURITY_AUDIT_DEEP.md`
- `secure_azure_saas_iac/docs/DR_RESTORE_FAILOVER_RUNBOOK.md`
- `secure_azure_saas_iac/docs/soc_playbooks/README.md`

Container Apps documentation:
- `secure_azure_container_apps/README.md`

## License

MIT
