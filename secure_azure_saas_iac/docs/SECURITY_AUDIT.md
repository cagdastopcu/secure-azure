# Security Audit Report

Date: 2026-05-01
Scope: Bicep IaC and GitHub Actions workflow in `secure_azure_saas_iac/`

## Summary
The baseline was good (managed identity usage, Key Vault purge protection, private endpoint, policy/tags). The main risks were around default exposure posture and private DNS completeness.

## Findings and Remediations

1. High: Web app default ingress posture could be interpreted as internet-facing
- Previous state: root defaults included broad ingress pattern and no explicit public-ingress switch.
- Risk: accidental exposure if deployed without strict parameter review.
- Remediation implemented:
  - Added `enablePublicWebIngress` parameter defaulted to `false`.
  - Wired `external` ingress to this parameter.
  - Added security comments describing why default is internal-only.

2. High: Key Vault had public network endpoint mode enabled
- Previous state: `publicNetworkAccess: Enabled` with firewall deny.
- Risk: larger attack surface and dependency on ACL correctness.
- Remediation implemented:
  - Set `publicNetworkAccess: Disabled`.
  - Set `networkAcls.bypass: None`.
  - Added comments documenting private-only access rationale.

3. High: Key Vault private endpoint lacked explicit private DNS zone wiring
- Previous state: private endpoint existed but no private DNS zone + VNet link + zone group.
- Risk: workloads may fail name resolution to private IP or fall back to public resolution patterns.
- Remediation implemented:
  - Added `privatelink.vaultcore.azure.net` private DNS zone.
  - Added VNet link for the ACA VNet.
  - Added private endpoint DNS zone group.

4. Medium: Workflow parallel runs could overlap
- Previous state: no concurrency controls or timeout.
- Risk: race conditions and longer token/runner exposure windows.
- Remediation implemented:
  - Added `concurrency` with `cancel-in-progress: true`.
  - Added `timeout-minutes: 20`.

## Security Controls Already Present (Kept)
- User-assigned managed identities for apps.
- Least-privilege Key Vault role (`Key Vault Secrets User`) per identity.
- Key Vault soft delete and purge protection.
- Internal worker app ingress (`external: false`).
- Policy baseline for allowed locations and required tags.
- OIDC pattern in pipeline (no long-lived cloud secret in workflow file).

## Residual Risks / Next Hardening Steps
- Replace action tags with pinned commit SHAs in workflow for stronger supply-chain integrity.
- Add policy assignments for deny public network access on data services used in future modules (Storage/SQL/etc.).
- Add Defender for Cloud onboarding and security contact settings as IaC.
- Add Azure Monitor private link strategy if your compliance posture requires private-only ingestion/query.
- Add environment protection rules in GitHub (required reviewers for deployment secrets).

## References
- Key Vault network security: https://learn.microsoft.com/en-us/azure/key-vault/general/how-to-azure-key-vault-network-security
- Secure Key Vault guidance: https://learn.microsoft.com/en-us/azure/key-vault/general/secure-key-vault
- ACA ingress model: https://learn.microsoft.com/azure/container-apps/ingress-overview
- Private DNS zone groups for private endpoints: https://learn.microsoft.com/en-us/azure/templates/microsoft.network/2023-11-01/privateendpoints/privatednszonegroups
- GitHub Actions security hardening: https://docs.github.com/actions/learn-github-actions/security-hardening-for-github-actions
