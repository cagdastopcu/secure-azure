# Secure Azure SaaS IaC - Deep Guide (From Zero)

This document explains the IaC system from first principles: what each Azure concept means, why each design choice exists, how the structure works, and how to operate it safely.

## 1. What This Project Is

This folder contains an **Infrastructure as Code (IaC)** implementation for a secure Azure SaaS platform.

- **IaC** means infrastructure is defined in code files, not manually clicked in portal.
- **Why it matters**:
  - Repeatable deployments
  - Auditable change history (Git)
  - Faster, safer environments
  - Easier security enforcement

This project uses **Bicep**, which compiles to **ARM** (Azure Resource Manager) deployments.

## 2. Core Azure Terms (Simple Definitions)

- **Azure Resource Manager (ARM)**: Azure control plane API that creates/manages resources.
- **Bicep**: Azure-native declarative language for ARM templates.
- **Resource Group (RG)**: Logical container for Azure resources.
- **Subscription**: Billing and governance boundary.
- **Tenant (Microsoft Entra tenant)**: Identity directory boundary.
- **Virtual Network (VNet)**: Private network boundary in Azure.
- **Subnet**: Smaller network segment inside VNet.
- **Private Endpoint**: Private IP path to Azure PaaS service (no internet path).
- **Private DNS Zone**: DNS mapping so service names resolve to private endpoint IPs.
- **Managed Identity**: Azure-managed identity for apps/services; avoids credentials in code.
- **Key Vault**: Secrets/keys/certificates service.
- **RBAC**: Role-Based Access Control for least-privilege authorization.
- **Azure Policy**: Governance rules to allow/deny/audit configurations.
- **Log Analytics Workspace**: Central log storage/query platform.
- **Application Insights**: App telemetry (traces, requests, dependencies, failures).
- **Azure Container Apps (ACA)**: Managed container runtime with autoscaling.
- **Ingress**: Incoming traffic configuration to an app (public or internal).
- **OIDC (OpenID Connect)**: Short-lived trust for CI/CD to cloud; no long-lived secret needed.
- **What-if**: ARM deployment preview showing proposed changes before apply.

## 3. Why This Architecture Exists

The design optimizes for four goals:

1. **Security by default**
- Internal-only app exposure by default.
- Key Vault public access disabled.
- Private endpoint + private DNS for secrets path.
- Managed identity instead of app secrets.

2. **Platform consistency**
- Shared tags and naming convention.
- Policy assignments for allowed regions and required tags.
- Modular structure reusable across envs.

3. **Operational visibility**
- Central logs and metrics through Log Analytics + App Insights.

4. **Scalable SaaS foundation**
- “Stamp” model for repeatable app slices.
- Easy extension for data, messaging, additional services.

## 4. Folder Structure and Why It Is Organized This Way

```text
secure_azure_saas_iac/
  main.bicep
  README.md
  docs/
    DEPLOYMENT.md
    LINE_BY_LINE_EXPLANATION.md
    SECURITY_AUDIT.md
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

### `main.bicep`
Root orchestrator. Calls all child modules in controlled order.

### `platform/`
Shared platform baseline resources.
- `network`: VNet/subnets for ACA and private endpoints.
- `monitoring`: logs/telemetry foundation.
- `policy`: governance assignments.

### `stamps/`
Repeatable deployable unit for workloads (runtime + security attachments).

### `workloads/`
Reserved for app/service-specific modules.

### `pipelines/`
CI/CD workflow templates with validation and what-if.

### `docs/`
Operational and security documentation.

## 5. Module-by-Module Design Decisions

## 5.1 Root Orchestrator (`main.bicep`)
Why needed:
- Single entrypoint for deployment.
- Passes shared parameters/tags once.
- Wires module outputs safely (e.g., subnet IDs, workspace IDs).

Security-relevant defaults:
- `enablePublicWebIngress=false` (internal by default).
- CIDR controls required if public ingress is enabled.

## 5.2 Network Module (`platform/network/main.bicep`)
What it creates:
- One VNet
- ACA infrastructure subnet (delegated)
- Private endpoint subnet

Why needed:
- Network segmentation and explicit trust boundaries.
- ACA delegation is required by service runtime.
- Private endpoint subnet isolates private service paths.

## 5.3 Monitoring Module (`platform/monitoring/main.bicep`)
What it creates:
- Log Analytics Workspace
- Workspace-based Application Insights

Why needed:
- Unified telemetry for troubleshooting and security monitoring.
- Baseline observability required for production operations.

## 5.4 Policy Module (`platform/policy/security-baseline.bicep`)
What it assigns:
- Allowed locations policy.
- Required tag+value policies (`environment`, `project`, `managedBy`).

Why needed:
- Prevent drift and non-compliant deployments.
- Enforce governance controls early.

## 5.5 ACA Stamp (`stamps/aca-stamp/main.bicep`)
What it creates:
- ACA managed environment
- Key Vault (private-only)
- User-assigned managed identities
- Web app + internal worker app
- Key Vault private endpoint
- Private DNS zone + VNet link + PE zone group

Why needed:
- Provides a secure, reusable runtime slice for SaaS workloads.
- Keeps secret access private and identity-based.
- Separates public-facing and internal service paths.

## 6. Security Model (Practical)

## 6.1 Identity and Access
- Workloads authenticate using managed identities.
- Key Vault access granted with least-privilege role (`Key Vault Secrets User`).

Why:
- Eliminates embedded credentials.
- Reduces blast radius if one app identity is compromised.

## 6.2 Network Security
- Key Vault public network access disabled.
- Private endpoint used for secret retrieval.
- Private DNS ensures correct private name resolution.
- Worker app has internal ingress only.

Why:
- Reduces internet attack surface.
- Prevents accidental secret access over public routes.

## 6.3 Governance
- Policy guardrails enforce allowed regions and mandatory tags.

Why:
- Prevents accidental non-compliant resource creation.
- Improves cost/security/accountability reporting.

## 6.4 CI/CD Security
- OIDC auth model in workflow (no static cloud secret in YAML).
- `what-if` before apply.
- Concurrency and timeout controls.

Why:
- Limits credential risk and operational race conditions.

## 7. Deployment Flow (How It Works)

1. Run deployment with parameters.
2. Root module deploys monitoring/network/policy.
3. Root module deploys ACA stamp using output dependencies.
4. Outputs provide environment name/FQDN/workspace references.

Why this order:
- Stamp depends on network and monitoring outputs.
- Security and governance should be established before workload growth.

## 8. Environment Strategy (dev/test/prod)

Recommended:
- Separate resource groups per environment at minimum.
- Prefer separate subscriptions for stronger isolation in mature setups.
- Use parameter files (`*.bicepparam`) per environment.

Why:
- Isolation reduces cross-environment blast radius.
- Cleaner RBAC and cost boundaries.

## 9. How to Extend Safely

When adding new modules (SQL, Storage, Redis, Service Bus, etc.):
- Prefer private endpoint connectivity.
- Disable public access if service supports it.
- Use managed identity auth where possible.
- Add policy controls for each new service type.
- Add diagnostics routing to Log Analytics.

## 10. Known Limits / Important Notes

- Azure CLI not guaranteed on every local machine; validate toolchain before deployment.
- Built-in policy IDs can evolve; verify IDs in tenant periodically.
- Internal default ingress may require fronting with gateway/front door for public apps.

## 11. Quick Command Reference

```bash
# Create RG
az group create --name rg-saas-dev-platform --location westeurope

# Deploy root
az deployment group create \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas

# Validate only
az deployment group validate \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas

# Preview changes
az deployment group what-if \
  --resource-group rg-saas-dev-platform \
  --template-file secure_azure_saas_iac/main.bicep \
  --parameters location=westeurope environment=dev projectPrefix=saas
```

## 12. Why This Matters for a SaaS Company

A SaaS platform needs speed and trust simultaneously.
This structure gives:
- Fast repeatable environments
- Security-first defaults
- Lower operational risk
- Clear upgrade path from startup to enterprise scale

## 13. Related Docs in This Folder

- `docs/DEPLOYMENT.md`: deployment commands and practical notes
- `docs/LINE_BY_LINE_EXPLANATION.md`: code-level walkthrough
- `docs/SECURITY_AUDIT.md`: hardening findings and remediations

