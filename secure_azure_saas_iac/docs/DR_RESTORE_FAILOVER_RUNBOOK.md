# Disaster Recovery Restore and Failover Runbook (SaaS Platform)

## Purpose
This runbook defines how the platform team restores service after:
- Logical data corruption
- Accidental deletion
- Regional outage
- Prolonged platform dependency outage

It exists because the blueprint requires **tested restore/failover runbooks**, not only backup configuration.

## Scope
- Azure SQL Database in `stamps/data-stamp/main.bicep`
- Storage account in `stamps/data-stamp/main.bicep`
- Service Bus namespace in `stamps/data-stamp/main.bicep`
- Container Apps workloads in `stamps/aca-stamp/main.bicep`

## Recovery Objectives (Set per environment)
- `prod` target RTO: 2 hours
- `prod` target RPO: 15 minutes
- `test/dev` target RTO: 8 hours
- `test/dev` target RPO: 24 hours

Adjust these with business owners if contractual SLAs are stricter.

## Preconditions
- On-call has `Contributor` on workload subscription.
- Break-glass access path documented and tested.
- Monitoring/alerts are routed to SOC + platform on-call.
- IaC deployment identity can run `az deployment group create`.

## Scenario A: SQL Data Corruption (Point-in-Time Restore)
1. Confirm corruption timestamp from app logs and SQL audit logs.
2. Select restore point just before corruption event.
3. Restore database to new name (`<db>-restore-<timestamp>`).
4. Validate schema + row counts with application smoke queries.
5. Switch application connection to restored database via Key Vault secret update.
6. Monitor error rate and latency for 30 minutes.
7. Decommission old database only after formal incident closure.

## Scenario B: Regional Outage (Geo Restore Path)
1. Declare incident severity and open war room.
2. Deploy baseline IaC to paired recovery region using same code revision.
3. Restore SQL using geo-available backups in recovery region.
4. Recreate Service Bus/Storage dependencies from IaC outputs.
5. Deploy application stamp and update DNS/front-door routing.
6. Validate auth, API, queue processing, and tenant-critical flows.
7. Communicate customer impact and recovery status every 30 minutes.

## Scenario C: App Runtime Compromise
1. Revoke compromised identities/secrets immediately.
2. Stop affected Container Apps revisions.
3. Deploy known-good image digest and force new revision.
4. Rotate Key Vault secrets and rebind secret references.
5. Run forensic log export and preserve evidence.

## Validation Checklist (Post-Recovery)
- Health probes green for all public endpoints.
- Queue backlog returning to normal.
- Error budget burn rate back to baseline.
- No unauthorized sign-ins or policy violations during recovery.
- Incident timeline and root cause documented.

## Drill Cadence
- Quarterly tabletop exercise.
- Semi-annual live restore drill in non-production.
- Annual cross-region failover simulation.

## Evidence to Keep
- Incident ticket ID
- Commands executed and deployment IDs
- Restore timestamps and chosen backup point
- Validation query outputs and synthetic test results
- Customer communication timeline

## References
- Azure SQL long-term retention and restore concepts:
  - https://learn.microsoft.com/en-us/azure/azure-sql/database/long-term-retention-overview?view=azuresql
- Azure SQL backup redundancy settings:
  - https://learn.microsoft.com/en-us/azure/azure-sql/database/automated-backups-change-settings?tabs=powershell&view=azuresql
- Azure Firewall egress control with default route model:
  - https://learn.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal-policy
