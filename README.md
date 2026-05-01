# Secure Azure SaaS IaC

Production-oriented Infrastructure as Code scaffold for building a secure, multi-tenant SaaS platform on Azure using Bicep (ARM-native), Azure Container Apps, and policy-driven governance.

## What This Repository Provides
- Secure Azure SaaS blueprint documentation
- Modular Bicep IaC scaffold under `secure_azure_saas_iac/`
- Platform baseline modules for:
  - Networking (VNet + delegated ACA subnet + private endpoint subnet)
  - Monitoring (Log Analytics + Application Insights)
  - Policy baseline (allowed locations + required tags)
- Application stamp module for:
  - Azure Container Apps environment
  - Public web app + internal worker app
  - User-assigned managed identities
  - Key Vault with purge protection + private endpoint
- GitHub Actions IaC validation/what-if pipeline template

## Repository Structure
```text
secure_azure_saas_iac/
  main.bicep
  docs/DEPLOYMENT.md
  pipelines/github-actions-iac.yml
  platform/
    monitoring/main.bicep
    network/main.bicep
    policy/security-baseline.bicep
  stamps/
    aca-stamp/main.bicep
  workloads/
    services/
```

## Quick Start
1. Create a resource group:
```bash
az group create --name rg-saas-dev-platform --location westeurope
```
2. Deploy:
```bash
az deployment group create \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

## Security Notes
- Replace default ingress CIDR (`0.0.0.0/0`) before production.
- Keep CI/CD secretless with OIDC federation.
- Extend policy baseline with your organization initiatives and compliance controls.

## Recommended Next Steps
- Add private DNS zones and VNet links for private endpoint resolution.
- Add data layer modules (PostgreSQL/Azure SQL, Redis, Service Bus).
- Add environment parameter files (`*.bicepparam`) for dev/test/prod.
- Add Defender for Cloud onboarding module and diagnostic settings policies.

## License
MIT (or your preferred license).
