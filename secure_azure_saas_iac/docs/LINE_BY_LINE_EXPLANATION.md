# Line-by-Line Explanation

This document explains each IaC file line-by-line using line ranges.

## File: `main.bicep`
- Lines 1-4: File-level comments define this file as the root orchestrator that composes all modules.
- Line 5: `targetScope = 'resourceGroup'` means deployments happen at resource-group scope.
- Lines 7-32: Parameter block defines deployment inputs (location, environment, naming prefix, address spaces, logging retention, image, ingress CIDRs).
- Lines 34-40: Shared `tags` object is built once and passed to modules for consistent governance metadata.
- Lines 42-53: `monitoring` module call creates observability foundation and outputs workspace IDs/keys.
- Lines 55-67: `network` module call creates VNet and subnets, then exports subnet resource IDs.
- Lines 70-82: `securityBaseline` module call assigns built-in policies for allowed regions and required tags.
- Lines 84-99: `acaStamp` module call deploys runtime stack using outputs from monitoring/network.
- Lines 101-103: Outputs surface key post-deploy values (workspace, ACA env, public FQDN).

## File: `platform/network/main.bicep`
- Lines 1-5: Doc comments describe purpose of network baseline and subnet intent.
- Line 6: Resource-group deployment scope.
- Lines 8-14: Input parameters for location/naming/CIDRs/tags.
- Lines 16-18: Derived names for VNet and subnets.
- Lines 20-56: `virtualNetworks` resource defines address space and two subnets.
- Lines 29-41: ACA subnet includes delegation to `Microsoft.App/environments` required by ACA environment.
- Lines 43-50: Private endpoint subnet disables PE network policies as required by Azure PE behavior.
- Lines 58-60: Outputs expose VNet/subnet IDs for dependent modules.

## File: `platform/monitoring/main.bicep`
- Lines 1-3: Module documentation notes this is observability baseline.
- Line 4: Resource-group deployment scope.
- Lines 6-13: Parameters for location, naming, retention, tags.
- Lines 15-16: Deterministic names for Log Analytics and App Insights.
- Lines 18-30: Log Analytics workspace resource config (PerGB2018 SKU, retention, RBAC-centric log access).
- Lines 32-43: Application Insights resource linked to workspace via `WorkspaceResourceId`.
- Lines 45-48: Outputs provide IDs/secrets/connection string for downstream modules and tooling.

## File: `platform/policy/security-baseline.bicep`
- Lines 1-4: Module documentation and governance purpose.
- Line 5: Resource-group deployment scope.
- Lines 7-23: Parameters include assignment location, allowed regions, expected tag values.
- Lines 25-26: Built-in policy definition IDs for allowed locations and required-tag-and-value.
- Lines 28-44: Assignment to restrict resource deployments to approved regions.
- Lines 46-65: Assignment enforcing `environment` tag with expected value.
- Lines 67-86: Assignment enforcing `project` tag with expected value.
- Lines 88-107: Assignment enforcing `managedBy` tag with expected value.
- Lines 109-114: Output array of assignment names for reporting and operations.

## File: `stamps/aca-stamp/main.bicep`
- Lines 1-7: File-level comments describe the secure app stamp composition.
- Line 8: Resource-group deployment scope.
- Lines 10-21: Inputs for naming/runtime/networking/telemetry/logging and tags.
- Lines 23-26: Derived names for ACA environment, Key Vault, and app resources.
- Lines 28-54: Managed environment creation with delegated subnet and Log Analytics app logs.
- Lines 56-82: Key Vault creation with RBAC auth, soft delete, purge protection, and firewall deny-by-default.
- Lines 84-94: User-assigned identities for web and worker apps.
- Lines 96-119: Key Vault Secrets User role assignments for each identity.
- Lines 121-179: Public web app with ingress, CIDR restrictions, scale, image, and env vars.
- Lines 181-237: Internal worker app with no external ingress and its own scaling profile.
- Lines 239-260: Private endpoint from PE subnet to Key Vault (`groupIds: ['vault']`).
- Lines 262-264: Outputs expose ACA environment name, web FQDN, and Key Vault name.

## File: `pipelines/github-actions-iac.yml`
- Lines 1-2: Workflow-level comment clarifies CI intent and OIDC auth model.
- Lines 3-9: Workflow trigger and permissions (`id-token: write` for OIDC, `contents: read` for checkout).
- Lines 11-16: Single job definition with runner and environment variables.
- Lines 17-18: Checkout source repository.
- Lines 20-25: Azure login through federated identity (no client secret in workflow file).
- Lines 27-30: Ensure target resource group exists (idempotent operation).
- Lines 32-38: Validate Bicep deployment (server-side ARM validation).
- Lines 40-45: Run `what-if` to preview changes before apply.

## Notes
- This explanation follows the current committed files and line ranges may shift as files evolve.
- For strict production hardening, tighten `allowedIngressCidrs` and extend policy baseline with organization-specific initiatives.
