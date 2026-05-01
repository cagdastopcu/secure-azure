# Deep Security Audit (Round 2)

Date: 2026-05-01
Scope: `secure_azure_saas_iac` Bicep modules and GitHub Actions workflow
Method: configuration review against Azure/GitHub hardening best practices

## Executive Summary
The stack is now substantially hardened for an early-stage SaaS baseline:
- Private-only Key Vault access with Private Endpoint + Private DNS.
- Internal-by-default app ingress and explicit TLS enforcement.
- Managed identity-first secret access model.
- Policy guardrails for regions and mandatory tags.
- CI security improvements (OIDC, short timeout, no persisted checkout credentials, strict shell mode).

## Findings

## Critical
- None identified in current template set.

## High
1. Public ingress must remain opt-in only.
- Status: mitigated.
- Control: `enablePublicWebIngress=false` default and CIDR restrictions.
- Why it matters: prevents accidental internet exposure of SaaS entrypoint.

2. Secret store internet exposure.
- Status: mitigated.
- Control: Key Vault `publicNetworkAccess: Disabled`, private endpoint path only.
- Why it matters: reduces external attack surface and data exfiltration vectors.

3. Private endpoint DNS completeness.
- Status: mitigated.
- Control: private DNS zone + VNet link + PE zone group.
- Why it matters: ensures private resolution and reliable service-to-service connectivity.

## Medium
1. Workflow credential persistence on checkout.
- Status: mitigated.
- Control: `persist-credentials: false`.
- Why it matters: reduces token reuse risk in later steps.

2. Workflow shell failure behavior.
- Status: mitigated.
- Control: `set -euo pipefail` in every run block.
- Why it matters: prevents partial-success states and silent command errors.

3. Output verbosity and accidental data leakage.
- Status: mitigated.
- Control: `AZURE_CORE_OUTPUT=none`.
- Why it matters: lowers chance of sensitive value exposure in logs.

## Low
1. Action pinning uses major tags (`@v4`, `@v2`) not full commit SHAs.
- Status: accepted risk for now.
- Recommendation: pin third-party actions to full commit SHA for maximum supply-chain integrity.

2. Policy baseline coverage is minimal.
- Status: partially mitigated.
- Recommendation: add broader policy initiative coverage as modules expand (storage/sql public access deny, diagnostics required, approved SKUs).

## Security-Critical Controls Checklist
- Managed identities for runtime auth: Yes
- Key Vault RBAC + purge protection: Yes
- Key Vault public endpoint disabled: Yes
- Key Vault private endpoint + DNS plumbing: Yes
- Worker app internal-only ingress: Yes
- Web app public ingress opt-in: Yes
- Ingress cleartext disabled: Yes
- Region/tag governance policies: Yes
- OIDC in CI: Yes
- CI timeout/concurrency controls: Yes

## Residual Risks and Next Hardening Actions
1. Pin GitHub actions to commit SHAs.
2. Add CODEOWNERS protection for IaC and workflow paths.
3. Add branch protection requiring PR reviews and status checks.
4. Add policy modules for diagnostic settings enforcement.
5. Add Defender for Cloud onboarding module and security contacts.
6. Add private link strategy for Log Analytics if compliance requires private-only ingestion/query.

## Files Updated in This Audit Round
- `stamps/aca-stamp/main.bicep`
- `pipelines/github-actions-iac.yml`

## References
- Key Vault network security: https://learn.microsoft.com/en-us/azure/key-vault/general/how-to-azure-key-vault-network-security
- Secure Key Vault guidance: https://learn.microsoft.com/en-us/azure/key-vault/general/secure-key-vault
- ACA ingress: https://learn.microsoft.com/azure/container-apps/ingress-overview
- GitHub Actions hardening: https://docs.github.com/actions/learn-github-actions/security-hardening-for-github-actions
