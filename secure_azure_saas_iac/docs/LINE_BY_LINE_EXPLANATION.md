# Line-by-Line Explanation

This document explains the current code using line ranges and highlights security-relevant lines.

## File: `main.bicep`
- Lines 1-4: Root-file comments define orchestration purpose.
- Line 5: `targetScope='resourceGroup'` sets deployment boundary.
- Lines 7-33: Core parameters (location/env/prefix/network/log/image/CIDRs).
- Lines 35-37: `enablePublicWebIngress=false` default is security-first internal posture.
- Lines 39-45: Shared tags for governance metadata.
- Lines 47-58: Monitoring module deployment.
- Lines 60-72: Network module deployment.
- Lines 74-86: Policy baseline module deployment.
- Lines 87-103: ACA stamp deployment with network/monitoring outputs and public-ingress toggle.
- Lines 105-107: Operational outputs.

## File: `platform/network/main.bicep`
- Lines 1-5: Purpose comments for segmentation and subnet roles.
- Line 6: Resource-group scope.
- Lines 8-14: Inputs.
- Lines 16-18: Deterministic resource names.
- Lines 20-56: VNet + subnets.
- Lines 29-41: ACA subnet delegation to `Microsoft.App/environments`.
- Lines 43-50: PE subnet with `privateEndpointNetworkPolicies='Disabled'`.
- Lines 58-60: Subnet/VNet outputs.

## File: `platform/monitoring/main.bicep`
- Lines 1-3: Monitoring baseline intent.
- Line 4: Scope.
- Lines 6-13: Inputs.
- Lines 15-16: Resource names.
- Lines 18-30: Log Analytics workspace.
- Lines 32-43: Workspace-based App Insights.
- Lines 45-48: Outputs used by stamp/pipeline.

## File: `platform/policy/security-baseline.bicep`
- Lines 1-4: Governance baseline comments.
- Line 5: Scope.
- Lines 7-23: Parameters.
- Lines 25-26: Built-in policy definition IDs.
- Lines 28-44: Allowed locations policy assignment.
- Lines 46-65: Required `environment` tag policy.
- Lines 67-86: Required `project` tag policy.
- Lines 88-107: Required `managedBy` tag policy.
- Lines 109-114: Assignment-name outputs.

## File: `stamps/aca-stamp/main.bicep`
- Lines 1-7: Stamp purpose comments.
- Line 8: Scope.
- Lines 10-23: Inputs (including `enablePublicWebIngress`).
- Lines 25-29: Name derivations + VNet ID derivation.
- Lines 31-57: ACA environment with Log Analytics integration.
- Lines 59-89: Key Vault with RBAC, soft-delete, purge protection, `publicNetworkAccess='Disabled'`, firewall deny and no bypass.
- Lines 91-101: User-assigned identities.
- Lines 103-126: Least-privilege Key Vault role assignments.
- Lines 128-192: Web app configuration.
- Security lines:
  - `external: enablePublicWebIngress` (opt-in public exposure)
  - `allowInsecure: false` (TLS-only ingress)
  - `ipSecurityRestrictions` (CIDR allow-list)
- Lines 194-253: Internal worker app.
- Security lines:
  - `external: false` (internal-only)
  - `allowInsecure: false` (reject plain HTTP)
- Lines 255-276: Key Vault private endpoint.
- Lines 278-285: Private DNS zone for Key Vault private link.
- Lines 287-298: DNS VNet link.
- Lines 300-314: Private endpoint DNS zone group.
- Lines 316-318: Outputs.

## File: `.github/workflows/iac-deploy.yml`
- Lines 1-2: Workflow security intent comments.
- Lines 3-8: Trigger (`main` + `master`) to support current and legacy default branch names.
- Lines 9-12: Concurrency control to avoid overlapping runs.
- Lines 14-18: Minimal token permissions.
- Lines 20-25: Job, runner, timeout.
- Lines 26-30: Env including `AZURE_CORE_OUTPUT=none`.
- Lines 31-37: Checkout with `persist-credentials: false` and shallow fetch.
- Lines 39-44: OIDC Azure login.
- Lines 46-50: RG create with `set -euo pipefail`.
- Lines 52-59: Validate with strict shell mode and explicit template path `secure_azure_saas_iac/main.bicep`.
- Lines 61-68: What-if with strict shell mode and explicit template path `secure_azure_saas_iac/main.bicep`.

## Notes
- Line numbers can shift as files evolve.
- Security rationale comments are embedded directly next to security-sensitive fields in code.


For parameter-by-parameter Azure behavior details, see docs/CODE_DEEP_DIVE.md.



For exhaustive per-line commentary, see docs/EVERY_LINE_EXPLANATION.md.

