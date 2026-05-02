# Secure Azure SaaS IaC

This folder is a full Infrastructure as Code blueprint implementation for a secure SaaS platform on Azure.
It is designed to be understandable for beginners and useful for platform, DevOps, and security engineers.

## 1. What This Project Is

This project is a modular Bicep deployment that creates:
- Platform foundation resources
- Application runtime foundation
- Data and integration foundation
- Governance and monitoring controls
- Optional advanced controls (Firewall, APIM, Front Door, Defender onboarding)

The main idea is:
- Deploy secure defaults first
- Keep risky features optional and explicit
- Make security settings visible and testable in code

## 2. Core Azure Concepts (Plain Language)

- `Bicep`: Azure's Infrastructure as Code language. You write resources in readable syntax and Azure deploys ARM resources from it.
- `ARM`: Azure Resource Manager. The control plane that creates/updates Azure resources.
- `Resource Group`: A logical container for resources that are deployed and managed together.
- `Module`: A reusable Bicep file for one domain (network, monitoring, app stamp, data stamp).
- `Output`: A value produced by one module and passed to another module (for example subnet ID).
- `Managed Identity`: An identity for an Azure service so code can authenticate to other Azure services without passwords.
- `Private Endpoint`: A private IP address in your VNet for a PaaS service (Storage, SQL, Key Vault, etc.), so traffic does not use public internet endpoints.
- `Private DNS Zone`: Internal DNS records mapping service FQDNs to private endpoint IPs.
- `Container Apps`: Managed container runtime for web APIs, workers, and jobs.
- `Azure Firewall`: Central outbound/inbound network inspection service.
- `Route Table`: Network rule table that tells a subnet where to send traffic (for example, default route to firewall).
- `PITR`: Point-in-time restore, short-term SQL backup restore window.
- `LTR`: Long-term SQL backup retention for compliance and deep-history recovery.
- `Azure Policy`: Guardrails that audit or deny deployments violating rules (location, tags, public network settings, etc.).

## 3. Architecture in This Codebase

Deployment starts in `main.bicep` and orchestrates modules in this order:
1. Monitoring (Log Analytics, App Insights)
2. Networking (VNet, subnets, optional DDoS, optional Firewall egress)
3. Governance policies
4. Optional subscription controls (Defender, budget, activity log export)
5. Data stamp
6. ACA application stamp
7. Optional edge/API controls (Front Door, APIM)

This sequencing matters because later modules depend on IDs from earlier modules.
Example:
- ACA stamp needs subnet IDs from network module
- Data stamp needs private endpoint subnet ID

## 4. Folder-by-Folder Map

`platform/`
- Shared platform controls used by all workloads.

`platform/network/main.bicep`
- Builds VNet, ACA delegated subnet, private-endpoint subnet.
- Optional: Azure Firewall egress pattern:
  - dedicated `AzureFirewallSubnet`
  - Firewall Policy
  - Firewall instance
  - route table forcing ACA subnet default route to Firewall

`platform/monitoring/main.bicep`
- Log Analytics workspace and Application Insights.

`platform/policy/security-baseline.bicep`
- Baseline policy assignments for region and required tags.

`platform/policy/public-network-deny.bicep`
- Optional deny assignments to reduce public network exposure risk.

`platform/security/defender-onboarding.bicep`
- Optional subscription-level Defender for Cloud plan onboarding.

`platform/api/main.bicep`
- Optional Azure API Management deployment.

`platform/edge/frontdoor.bicep`
- Optional Front Door + WAF path for internet-facing architecture.

`stamps/`
- Reusable deployment units for runtime and data capabilities.

`stamps/aca-stamp/main.bicep`
- Container Apps environment
- Key Vault with private endpoint and private DNS link
- User-assigned identities for web/worker
- Public web ingress is optional
- Worker service is internal-only

`stamps/data-stamp/main.bicep`
- Storage + Service Bus always
- SQL/Redis/Event Grid optional by parameter
- Private endpoints and private DNS integration for enabled services
- SQL resilience controls:
  - `requestedBackupStorageRedundancy`
  - short-term backup policy
  - long-term backup policy

`workloads/services/`
- Reusable service-level modules for API, onboarding, and queue job patterns.

`tests/`
- Scripted quality/security checks used locally and in CI.

## 5. Security Model Used Here

Security defaults in current code:
- Private-first networking for data and secrets services
- Key Vault public network access disabled
- HTTPS-only ingress for Container Apps (`allowInsecure: false`)
- Managed identity pattern to avoid embedding credentials
- Optional Firewall inspected egress path
- Policy assignments for governance consistency
- Backup and restore resilience controls for SQL

Why this matters:
- Most cloud incidents come from misconfiguration and overexposure, not zero-day exploits.
- Secure defaults reduce blast radius from human mistakes.

## 6. How the Firewall Egress Pattern Works

When `enableAzureFirewallForEgress=true`:
1. Code creates `AzureFirewallSubnet`.
2. Code deploys Firewall Policy + Firewall + static Standard Public IP.
3. Code creates route table with `0.0.0.0/0` next hop = Firewall private IP.
4. Code attaches this route table to the ACA infrastructure subnet.

Result:
- Outbound traffic from ACA subnet is forced through Firewall.
- Security team can inspect and control outbound destinations with policy/rules.

## 7. How SQL Backup Resilience Works

The SQL database module configures:
- `requestedBackupStorageRedundancy`: where automated backups are replicated (`Local|Zone|Geo|GeoZone`)
- `backupShortTermRetentionPolicies`: PITR window and differential backup interval
- `backupLongTermRetentionPolicies`: weekly/monthly/yearly retention windows

Operational meaning:
- Short-term retention helps undo recent accidents.
- Long-term retention supports compliance and late-detected incidents.
- Geo/GeoZone backup redundancy supports regional disaster recovery options.

## 8. Main Parameters You Will Actually Touch

From `main.bicep`:
- Environment and naming:
  - `location`
  - `environment`
  - `projectPrefix`
- Networking:
  - `vnetAddressPrefix`
  - `acaInfraSubnetPrefix`
  - `privateEndpointSubnetPrefix`
  - `enableAzureFirewallForEgress`
- Runtime exposure:
  - `enablePublicWebIngress`
  - `allowedIngressCidrs`
- Data choices:
  - `deploySql`
  - `deployRedis`
  - `deployEventGrid`
- SQL resilience:
  - `sqlBackupStorageRedundancy`
  - `sqlShortTermRetentionDays`
  - `enableSqlLongTermRetention`
- Governance toggles:
  - `deployDefenderOnboarding`
  - `deployAdvancedPublicNetworkDenyPolicies`
  - `deploySubscriptionActivityLogExport`

## 9. Deployment and Validation Flow

Recommended flow:
1. `az deployment group what-if`
2. Deploy to `dev`
3. Run tests:
  - `tests/scripts/validate-iac.ps1`
  - `tests/scripts/assert-security.ps1`
4. Promote to test/prod with controlled approvals

## 10. Test Scripts (What They Do)

`tests/scripts/validate-iac.ps1`
- Finds all `.bicep` files
- Builds each file through Azure CLI Bicep
- Fails if syntax/type/module references break
- Includes robust Azure CLI path fallback for Windows environments

`tests/scripts/assert-security.ps1`
- Checks source code for required secure defaults and critical resources
- Fails fast if a baseline control is removed

This gives a simple but effective "guardrail CI" pattern.

## 11. Known Warning Context

Current builds pass, but some non-blocking warnings remain in modules.
These are mostly:
- linter style warnings (`use-parent-property`, `no-unused-params`)
- provider type-schema warnings for some properties that may still work at runtime

Treat warnings as technical debt backlog and clean gradually.

## 12. DR and Incident Operations Docs

- Disaster recovery runbook:
  - `docs/DR_RESTORE_FAILOVER_RUNBOOK.md`
- SOC playbooks catalog:
  - `docs/soc_playbooks/README.md`

These docs describe operational response after deployment, not just provisioning.

## 13. Practical Usage Advice

- Start with defaults in `dev`.
- Turn on public ingress only for endpoints that must be public.
- Keep worker/onboarding services internal.
- Use Firewall egress mode for stricter production controls.
- Keep SQL backup redundancy and retention explicitly set, not implicit.

## 14. References

- Blueprint source:
  - `AZURE_SAAS_PLATFORM_BLUEPRINT.md`
- Deployment details:
  - `docs/DEPLOYMENT.md`
- Security audits:
  - `docs/SECURITY_AUDIT.md`
  - `docs/SECURITY_AUDIT_DEEP.md`

## 15. License

MIT
