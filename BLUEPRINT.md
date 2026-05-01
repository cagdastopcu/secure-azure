# Azure SaaS Platform Blueprint (Secure, IaC-First)

## 1. Objective
Build a secure, scalable, and repeatable Azure platform that can provision the full infrastructure needed for a SaaS company using ARM-native Infrastructure as Code (Bicep), Azure Container Apps, and enterprise landing zone practices.

## 2. Architecture Principles
- Cloud Adoption Framework (CAF) aligned landing zone first
- Azure Well-Architected Framework balance: Reliability, Security, Cost, Operational Excellence, Performance
- Platform engineering model: centralized guardrails, decentralized app delivery
- IaC as source of truth (Bicep/ARM), policy as code, identity-first security

## 3. Target Reference Architecture
- Edge and protection:
  - Azure Front Door Premium
  - Web Application Firewall (WAF)
  - DDoS strategy for internet-facing services
- API and application:
  - API Management (optional, based on monetization/governance need)
  - Azure Container Apps Environment
  - External ingress only for public endpoints
  - Internal ingress for east-west private services
- Data and state:
  - Azure SQL or PostgreSQL Flexible Server
  - Azure Storage accounts
  - Azure Cache for Redis
- Integration:
  - Azure Service Bus
  - Event Grid
- Identity and access:
  - Microsoft Entra ID / Entra External ID
  - Managed identities for workloads
- Secrets and keys:
  - Azure Key Vault via private endpoint
  - Soft delete + purge protection
- Networking:
  - Hub-spoke or Virtual WAN
  - Private DNS zones
  - Private endpoints for PaaS
  - Azure Firewall where required
- Operations and security:
  - Azure Monitor, Log Analytics, Application Insights
  - Microsoft Defender for Cloud
  - Azure Policy
- Resilience:
  - Service-native backups and geo-redundancy
  - Tested restore/failover runbooks

## 4. Multi-Tenant SaaS Strategy
Adopt a progressive isolation model:
- Tier 1 (cost optimized): shared app + shared DB schema with tenant discriminator
- Tier 2 (balanced): shared app + dedicated database per tenant
- Tier 3 (strict isolation): dedicated app/data stamp per tenant (subscription or region isolation)

This enables cost efficiency early and isolation upgrades as compliance or scale grows.

## 5. Landing Zone and Subscription Topology
Use management groups and subscriptions with clear separation:
- Platform subscription(s): networking, identity integration, governance, monitoring
- Connectivity/security subscription(s): hub/firewall/private DNS
- Workload subscriptions: dev, test, prod split by environment
- Optional dedicated subscriptions for high-sensitivity tenants

Core guardrails:
- Naming convention and mandatory tags
- Region allowlist
- Resource type/SKU controls
- Centralized policy assignments at MG/subscription scope

## 6. IaC Design (Bicep + ARM)
Recommended repo structure:

```text
/platform
  /management-groups
  /policy
  /network
  /monitoring
/stamps
  /aca-stamp
  /data-stamp
/workloads
  /services
/pipelines
/docs
```

Implementation practices:
- Use Bicep modules and Azure Verified Modules (AVM) where possible
- Parameterize by environment, region, tenant tier
- Use `what-if` in pull requests before deployment
- Use deployment stacks when lifecycle controls and managed cleanup are needed
- Keep modules small, composable, and versioned

## 7. Security Baseline (Required)
Identity and access:
- No long-lived secrets in CI/CD
- OIDC federation for pipeline identity
- Managed identities for runtime access
- Least privilege RBAC and PIM/JIT for privileged roles

Network and exposure:
- Private endpoints for data/secrets services
- Disable public network access where feasible
- NSG/Firewall rules with deny-by-default mindset

Data and secrets:
- Key Vault RBAC model
- Soft delete and purge protection enabled
- Key/certificate/secret rotation policy

Posture management:
- Defender for Cloud enabled across subscriptions
- Secure score tracked with remediation backlog
- Policy compliance dashboards and alerts

## 8. DevSecOps Delivery Model
Pipeline stages:
1. Validate
   - Bicep linting, template checks, policy checks
2. Plan
   - ARM/Bicep `what-if` preview artifact
3. Deploy non-production
   - Platform baseline then workload/stamp
4. Security checks
   - IaC scan, container image scan, dependency/license checks
5. Promote to production
   - Manual approvals + change control
6. Post-deploy verification
   - Smoke tests, alert health, SLO checks

Release practices:
- Blue/green or canary for app revisions in Container Apps
- Rollback defined per service and per stamp
- Immutable artifacts with signed image provenance (if available in toolchain)

## 9. SRE and Platform Operations
- Define SLO/SLI per product capability
- Configure ACA autoscaling (HTTP/concurrency/queue signals)
- Central dashboards for golden signals (latency, traffic, errors, saturation)
- Alert routing, incident runbooks, and on-call model
- Quarterly DR and restore drills
- Cost governance with budgets, anomaly alerts, and rightsizing cadence

## 10. 90-Day Learning and Build Roadmap
Weeks 1-2:
- CAF and landing zone fundamentals
- Management groups, subscriptions, RBAC model

Weeks 3-4:
- Bicep modules, AVM usage, policy-as-code
- OIDC federation in CI/CD

Weeks 5-6:
- Azure Container Apps environments
- Ingress patterns, internal service communication, managed identity

Weeks 7-8:
- Data and messaging integration with private networking
- Tenant-aware data architecture decisions

Weeks 9-10:
- Observability implementation and SRE baseline
- Backups, restore tests, runbooks

Weeks 11-12:
- Security hardening and production readiness review
- Operational game days and incident simulations

## 11. Suggested First Deliverables
- Baseline landing zone Bicep modules
- Security policy initiative assignments
- One reusable ACA application stamp module
- One end-to-end pipeline with OIDC + what-if + deploy
- Documentation for onboarding new services/teams

## 12. Success Criteria
- New SaaS environment can be provisioned from code in a repeatable way
- Policy/security controls are enforced automatically
- Deployments are auditable and low-touch
- Platform supports both shared and isolated tenant models
- Operational KPIs and security posture are visible and continuously improved

## 13. References (Official Microsoft Learn)
- Azure Well-Architected Framework:
  - https://learn.microsoft.com/en-us/azure/well-architected/what-is-well-architected-framework
- Cloud Adoption Framework:
  - https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/overview
- Azure landing zone design principles:
  - https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-principles
- Bicep modules and AVM:
  - https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/modules
- Deployment stacks:
  - https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks
- Bicep what-if:
  - https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if
- Azure Container Apps ingress:
  - https://learn.microsoft.com/azure/container-apps/ingress-overview
- Azure Container Apps managed identities:
  - https://learn.microsoft.com/en-us/azure/container-apps/managed-identity
- Key Vault security features:
  - https://learn.microsoft.com/en-us/azure/key-vault/general/security-features
- Azure Policy overview:
  - https://learn.microsoft.com/en-us/azure/governance/policy/overview
- Azure Front Door best practices:
  - https://learn.microsoft.com/en-us/azure/frontdoor/best-practices
- Azure DDoS best practices:
  - https://learn.microsoft.com/en-us/azure/ddos-protection/fundamental-best-practices
- Defender for Cloud:
  - https://learn.microsoft.com/azure/defender-for-cloud/defender-for-cloud-introduction
