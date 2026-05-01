# Deployment Guide

## Structure
- `main.bicep`: root deployment
- `platform/network/main.bicep`: vnet + subnets
- `platform/monitoring/main.bicep`: log analytics + app insights
- `stamps/aca-stamp/main.bicep`: container apps environment, apps, key vault, managed identities
- `pipelines/github-actions-iac.yml`: CI validation + what-if

## Deploy (dev)
```bash
az group create --name rg-saas-dev-platform --location westeurope
az deployment group create \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

## Security Notes
- Public web ingress is disabled by default (`enablePublicWebIngress=false`).
- If public ingress is enabled, set `allowedIngressCidrs` to strict trusted ranges.
- Use OIDC federation in GitHub Actions; do not use long-lived client secrets.
- Extend with policy assignments and private DNS zones per your enterprise landing zone.

