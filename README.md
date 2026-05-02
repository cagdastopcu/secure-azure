# Secure Azure SaaS (IaC Repository)

This repository contains a security-first Azure SaaS Infrastructure as Code baseline built with Bicep.
The goal is to provision repeatable platform infrastructure with strong default controls instead of adding security later.

## Current Code State

Implemented baseline under `secure_azure_saas_iac/`:
- Platform networking, monitoring, governance policy, and optional API gateway
- Azure Container Apps application stamp with managed identities and private Key Vault
- Data stamp with Storage, Service Bus, optional SQL/Redis/Event Grid, private endpoints, and private DNS
- Optional Azure Firewall egress-control pattern with forced default route from ACA subnet
- SQL backup resilience controls:
  - short-term retention (PITR)
  - long-term retention (weekly/monthly/yearly)
  - backup redundancy mode (`Local|Zone|Geo|GeoZone`)
- Security and validation scripts for CI
- SOC playbooks and DR restore/failover runbook documentation

## Repository Layout

```text
secure_azure_saas_iac/
  main.bicep
  README.md
  docs/
  platform/
  stamps/
  tests/
  workloads/
```

Key entrypoints:
- `secure_azure_saas_iac/main.bicep`: root orchestrator
- `secure_azure_saas_iac/README.md`: deep architecture and concept guide
- `secure_azure_saas_iac/tests/scripts/validate-iac.ps1`: compile validation
- `secure_azure_saas_iac/tests/scripts/assert-security.ps1`: security-default assertions

## Quick Start

```bash
az group create --name rg-saas-dev-platform --location westeurope

az deployment group create \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

## Documentation Index

- Architecture and terms:
  - `secure_azure_saas_iac/README.md`
- Deployment details:
  - `secure_azure_saas_iac/docs/DEPLOYMENT.md`
- Security audits:
  - `secure_azure_saas_iac/docs/SECURITY_AUDIT.md`
  - `secure_azure_saas_iac/docs/SECURITY_AUDIT_DEEP.md`
- DR operational runbook:
  - `secure_azure_saas_iac/docs/DR_RESTORE_FAILOVER_RUNBOOK.md`
- SOC operational playbooks:
  - `secure_azure_saas_iac/docs/soc_playbooks/README.md`

## License

MIT
