# Code Deep Dive: Parameters and Azure Behavior

This guide explains every important parameter and how each one affects Azure behavior at deployment/runtime.

## 1. Root Template: `main.bicep`

## 1.1 Parameters

### `location` (string)
- What it is: Azure region where regional resources are deployed (for example `westeurope`).
- How Azure uses it: ARM sends this to each regional resource API (`location` field).
- Why it matters:
  - Affects latency, data residency, pricing, and regional service availability.
  - Should align with allowed-locations policy.

### `environment` (`dev|test|prod`)
- What it is: lifecycle environment selector.
- How Azure uses it: not a direct Azure control-plane switch; used in naming/tags and policy expected values.
- Why it matters:
  - Prevents naming collisions.
  - Enables environment-specific filtering in logs/cost/governance.

### `projectPrefix` (string)
- What it is: naming prefix for resources.
- How Azure uses it: interpolated into resource names.
- Why it matters:
  - Supports operational discoverability and cost ownership.

### `vnetAddressPrefix` (CIDR)
- What it is: VNet address space (e.g., `10.40.0.0/16`).
- Azure behavior:
  - Defines parent private IP range for all subnets.
- Why it matters:
  - Must not overlap with peered/on-prem ranges.
  - Overlap breaks routing and private connectivity.

### `acaInfraSubnetPrefix` (CIDR)
- What it is: subnet for ACA managed environment infrastructure.
- Azure behavior:
  - Subnet delegated to `Microsoft.App/environments`.
- Why it matters:
  - Too small subnet can block scaling.
  - Delegation is required for environment creation.

### `privateEndpointSubnetPrefix` (CIDR)
- What it is: subnet for private endpoint NICs.
- Azure behavior:
  - PE NICs are attached here; target PaaS services exposed via private IP.
- Why it matters:
  - Keeps service-private interfaces separated from app runtime subnet.

### `logRetentionInDays` (int)
- What it is: Log Analytics data retention period.
- Azure behavior:
  - Controls retention lifecycle in workspace.
- Why it matters:
  - Tradeoff between compliance/forensics and storage cost.

### `bootstrapContainerImage` (string)
- What it is: initial container image URI.
- Azure behavior:
  - ACA pulls this image for web/worker containers.
- Why it matters:
  - For production, use trusted private registry and image scanning/signing process.

### `allowedIngressCidrs` (array)
- What it is: allow-list CIDR ranges for web ingress restrictions.
- Azure behavior:
  - ACA ingress creates IP security restriction rules.
- Why it matters:
  - Limits exposure to known reverse proxies/corporate egress ranges.

### `enablePublicWebIngress` (bool)
- What it is: toggle for internet exposure of web app endpoint.
- Azure behavior:
  - Mapped to ACA ingress `external` property.
- Why it matters:
  - `false` means internal-only endpoint within environment networking context.
  - Prevents accidental public exposure by default.

## 1.2 Modules

### Monitoring Module
- Inputs: location/prefix/env/retention/tags.
- Outputs used later:
  - workspace resource ID
  - workspace shared key

### Network Module
- Inputs: CIDRs and tags.
- Outputs used later:
  - ACA subnet resource ID
  - PE subnet resource ID

### Security Policy Module
- Inputs: allowed location list and required tag values.
- Behavior:
  - Assigns built-in policies at RG scope.

### ACA Stamp Module
- Inputs from above modules plus public ingress controls.
- Behavior:
  - Deploys runtime, identities, secret store, private network path.

## 2. Network Module: `platform/network/main.bicep`

### `vnet` resource
- Azure type: `Microsoft.Network/virtualNetworks`.
- Core fields:
  - `addressSpace.addressPrefixes`: VNet CIDR boundaries.
  - `subnets[]`: subnet definitions.

### ACA delegated subnet
- `delegations.serviceName = Microsoft.App/environments`
- Azure effect:
  - grants ACA service authority to place required infra components in subnet.

### Private endpoint subnet
- `privateEndpointNetworkPolicies = Disabled`
- Azure effect:
  - required compatibility mode for private endpoint NIC behavior.

Outputs are resource IDs (not names only), which is correct because downstream modules need full ARM IDs.

## 3. Monitoring Module: `platform/monitoring/main.bicep`

### Log Analytics workspace
- Type: `Microsoft.OperationalInsights/workspaces`.
- Important properties:
  - `sku: PerGB2018` pay-per-GB model.
  - `retentionInDays` governs data lifetime.
  - `enableLogAccessUsingOnlyResourcePermissions: true` prefers RBAC/resource permissions.

### Application Insights
- Type: `Microsoft.Insights/components`.
- Important properties:
  - `WorkspaceResourceId`: workspace-based mode.
  - `IngestionMode: LogAnalytics`: centralizes telemetry storage/query.

### Why output shared key?
- ACA environment log integration needs workspace customerId/sharedKey pair.
- Security note: key is sensitive and should remain in deployment scope only.

## 4. Policy Module: `platform/policy/security-baseline.bicep`

### Allowed locations policy assignment
- Built-in definition enforces regional boundary.
- Prevents creating resources in disallowed regions.

### Required tag+value assignments
- Enforces exact values for:
  - `environment`
  - `project`
  - `managedBy`
- Improves governance queryability, billing attribution, and drift control.

## 5. ACA Stamp Module: `stamps/aca-stamp/main.bicep`

## 5.1 ACA Managed Environment
- Type: `Microsoft.App/managedEnvironments`.
- `infrastructureSubnetId`: binds environment infra into delegated subnet.
- `appLogsConfiguration`: sends app logs to Log Analytics workspace.
- `workloadProfiles`: uses `Consumption` profile in this baseline.

## 5.2 Key Vault
- Type: `Microsoft.KeyVault/vaults`.
- Security-critical properties:
  - `enableRbacAuthorization: true` -> RBAC model instead of legacy access policies.
  - `enablePurgeProtection: true` -> protects from immediate permanent deletion.
  - `softDeleteRetentionInDays: 90` -> recoverable-delete window.
  - `publicNetworkAccess: Disabled` -> no public endpoint path.
  - `networkAcls.defaultAction: Deny` -> deny by default model.
  - `networkAcls.bypass: None` -> no broad trusted-service bypass.

## 5.3 Managed Identities + RBAC
- Creates two user-assigned managed identities (web/worker).
- Assigns `Key Vault Secrets User` role at vault scope to each identity.
- Azure runtime effect:
  - app can request token from IMDS/Azure identity endpoint
  - token authorizes Key Vault secret read operations

## 5.4 Web Container App
- `identity.type: UserAssigned` + linked identity object.
- Ingress settings:
  - `external: enablePublicWebIngress`
  - `allowInsecure: false` (TLS-only behavior)
  - `ipSecurityRestrictions` from CIDR list
- Scale:
  - `minReplicas` and `maxReplicas` set bounds for autoscaling behavior.

## 5.5 Worker Container App
- `external: false` -> internal-only endpoint.
- `allowInsecure: false` -> avoids plaintext ingress path.
- Separate identity and independent scale profile.

## 5.6 Private Endpoint + Private DNS

### Private Endpoint
- Type: `Microsoft.Network/privateEndpoints`.
- `privateLinkServiceId: keyVault.id`, `groupIds: ['vault']`.
- Azure effect:
  - creates private NIC to Key Vault private link target.

### Private DNS Zone
- Zone: `privatelink.vaultcore.azure.net`.
- VNet link connects zone to app network.
- DNS zone group associates PE and zone.
- Azure effect:
  - Key Vault FQDN resolves to private IP in linked VNet.
  - traffic stays on private network path.

## 6. Workflow: `.github/workflows/iac-deploy.yml`

## 6.1 Trigger and Permissions
- Pull request on `main` and `master` + manual dispatch.
- Minimal GitHub token permissions:
  - `id-token: write` for OIDC
  - `contents: read` for checkout

## 6.2 Static Tests Job
- Runs compile checks for all Bicep files.
- Runs security assertions against source baseline.
- Purpose:
  - fail early before Azure deployment calls.

## 6.3 Validate/What-if Job
- Depends on static-tests.
- OIDC login to Azure (no static cloud secret in workflow).
- `validate` checks template/resource schema and constraints.
- `what-if` previews actual change set.

## 6.4 Hardening Controls in Workflow
- `concurrency` with `cancel-in-progress` avoids overlapping runs.
- `timeout-minutes` constrains execution exposure window.
- `persist-credentials: false` prevents checkout token persistence.
- `set -euo pipefail` fail-fast shell mode for reliable CI behavior.
- `AZURE_CORE_OUTPUT=none` reduces chance of sensitive CLI output in logs.

## 7. Common Misconfigurations to Avoid

1. Overlapping CIDRs with corporate network or peer VNets.
2. Enabling public ingress without strict CIDR allow-list.
3. Removing private DNS zone group (breaks Key Vault private resolution).
4. Granting overly broad RBAC roles to app identities.
5. Skipping what-if in CI before deploy.

## 8. Environment Expansion Pattern

For prod maturity, add:
- per-environment `.bicepparam` files
- separate subscriptions for stronger blast-radius control
- policy extensions (diagnostics/public access deny for new data services)
- Defender for Cloud onboarding as code

## 9. Read Together With
- `README.md`
- `docs/LINE_BY_LINE_EXPLANATION.md`
- `docs/SECURITY_AUDIT.md`
- `docs/SECURITY_AUDIT_DEEP.md`
