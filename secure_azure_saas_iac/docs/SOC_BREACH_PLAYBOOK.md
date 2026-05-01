# SOC Breach Playbook (Azure SaaS)

## 1. Document Control
- Owner: Security Operations (SOC) Lead
- Approved by: CISO / Head of Engineering
- Version: 1.0
- Last updated: 2026-05-02
- Review cycle: Quarterly and after every Sev1/Sev2 incident

## 2. Purpose
This playbook gives SOC analysts a practical, step-by-step procedure to respond to a confirmed or suspected breach in this Azure SaaS platform.

It is aligned to:
- NIST SP 800-61 Rev. 3 incident response recommendations
- Azure incident response guidance
- Microsoft Defender XDR + Microsoft Sentinel incident operations

## 3. Scope
In scope systems:
- Azure Container Apps workloads (`web`, `worker`, service modules)
- Azure Key Vault
- Azure SQL / Storage / Service Bus / Event Grid / Redis (if enabled)
- Azure Front Door + WAF (if enabled)
- Microsoft Defender for Cloud / Defender XDR / Microsoft Sentinel
- GitHub Actions CI/CD with OIDC federation

Out of scope:
- Third-party systems not integrated into this Azure tenant
- Physical security incidents

## 4. Breach Scenario This Playbook Covers
Primary scenario:
- An attacker gains unauthorized access through identity compromise or vulnerable workload path.
- They attempt privilege escalation, secret/data access, persistence, or destructive actions.

Common indicators in this SaaS architecture:
- Unusual sign-ins or impossible travel on privileged identities
- Unexpected role assignments or policy changes
- Container App revision/image changes outside change window
- Key Vault secret reads by unusual principal
- Data access spikes (SQL/Storage) or exfiltration patterns
- New suspicious deployments from CI/CD identity

## 5. Severity Model and SLA
- Sev1 (Critical): Active breach with customer data impact or high-confidence exfiltration.
  - MTTA target: <= 15 minutes
  - Executive notification: <= 30 minutes
- Sev2 (High): Confirmed compromise without confirmed data loss.
  - MTTA target: <= 30 minutes
- Sev3 (Medium): Suspicious activity requiring deep investigation.
  - MTTA target: <= 4 hours

## 6. Roles and Responsibilities
- L1 SOC Analyst:
  - Triage alerts, enrich evidence, start incident record, execute approved containment checklist.
- L2 SOC Analyst / Incident Commander (IC):
  - Confirm scope, lead technical response, approve high-impact containment.
- Cloud Platform Engineer:
  - Execute Azure-level isolation and recovery changes.
- DevOps Engineer:
  - Lock CI/CD paths, revoke pipeline trust, validate deployment integrity.
- App Owner:
  - Validate business impact, support rollback and functional verification.
- Legal/Privacy:
  - Handle regulatory/customer notification decisions.
- Communications Lead:
  - Internal and external communications coordination.

## 7. Required Tooling and Evidence Sources
- Microsoft Defender portal (XDR incidents, entities, response actions)
- Microsoft Sentinel (incident queue, KQL, automation rules/playbooks)
- Azure Activity Log (subscription control plane events)
- Resource diagnostics in Log Analytics
- Container Apps revision history and traffic split
- Key Vault logs (secret/key access events)
- SQL/Storage audit logs
- GitHub audit logs + workflow run logs

## 8. Phase 0: Preparation (Must Exist Before Incident)
Checklist:
- Ensure all critical logs flow to Log Analytics/Sentinel.
- Keep incident templates in Sentinel for Sev1/Sev2.
- Pre-approve emergency access and break-glass accounts (MFA, monitored usage).
- Maintain contact tree and on-call rotation.
- Validate backup/restore runbooks (SQL PITR, app rollback, key recovery) quarterly.
- Confirm Defender for Cloud plans and policy compliance are enabled.
- Test at least one breach simulation every quarter.

## 9. Phase 1: Detection and Initial Triage
Trigger examples:
- Defender XDR incident created with high confidence
- Sentinel analytics rule on suspicious identity/access behavior
- Key Vault, SQL, or Storage anomaly alert
- Customer report of suspicious activity

L1 actions (first 15 minutes):
1. Open or create a single incident record in Defender/Sentinel.
2. Classify provisional severity using Section 5.
3. Preserve evidence:
   - Incident ID, alert IDs, impacted entities, timestamps (UTC), subscription/resource IDs.
4. Run quick scope checks:
   - Is privileged identity involved?
   - Is customer data store involved?
   - Is suspicious deployment/change involved?
5. Escalate to L2/IC for Sev1/Sev2 immediately.

## 10. Phase 2: Analysis and Scoping
Goals:
- Confirm if this is true positive.
- Determine blast radius.
- Identify initial access, persistence, lateral movement, and data impact.

Mandatory analysis tracks:
1. Identity track:
   - Review Entra sign-ins, risky sign-ins, token abuse indicators, privilege changes.
2. Workload track:
   - Check Container Apps revision changes, image digests, env var/secret reference changes.
3. Data track:
   - Review SQL/Storage/Key Vault access anomalies and export patterns.
4. Control-plane track:
   - Review Activity Log for IAM/policy/network diagnostic changes.
5. CI/CD track:
   - Review GitHub workflow runs, OIDC subject claims, unusual deployment actions.

Scope output required before containment completes:
- Affected identities
- Affected workloads/resources
- Earliest known malicious timestamp
- Confirmed/suspected data exposure level

## 11. Phase 3: Containment
Containment objective:
- Stop attacker actions safely while preserving evidence.

### 11.1 Short-Term Containment (Immediate)
Perform as approved by IC:
1. Disable/lock compromised user accounts and revoke sessions/tokens.
2. Remove emergency privileged role assignments added by attacker.
3. Isolate compromised Container App revision:
   - Shift traffic to last known good revision.
   - Deactivate malicious revision.
4. Disable suspicious workload identity permissions.
5. If CI/CD compromise suspected:
   - Disable affected GitHub workflows/environment deployments.
   - Rotate/restrict federated credentials and repo permissions.
6. Apply temporary network containment:
   - Tighten ingress CIDR allowlist.
   - Block suspicious IPs at WAF/Front Door if in use.

### 11.2 Long-Term Containment (Stabilization)
1. Implement least-privilege corrections for all touched identities.
2. Re-issue sensitive secrets/keys and update consumers.
3. Add temporary high-signal detection rules for same TTPs.
4. Enforce stricter change control until incident closure.

## 12. Phase 4: Eradication
1. Remove attacker persistence:
   - Rogue identities, federated credentials, backdoor configs, unauthorized automation.
2. Remove malicious artifacts:
   - Compromised app images/revisions, unauthorized scripts, suspicious runbooks/playbooks.
3. Patch root cause:
   - Vulnerable dependency, weak IAM, missing policy, misconfiguration.
4. Validate no remaining malicious activity for agreed observation window (for example 24-72h).

## 13. Phase 5: Recovery
Recovery objective:
- Safely restore normal operations with enhanced monitoring.

Steps:
1. Restore application/data from known good state if required:
   - SQL point-in-time restore if data tampering occurred.
   - Re-enable only trusted app revisions/images.
2. Re-enable production traffic gradually:
   - Canary approach where possible.
3. Force credential and key rotation:
   - Affected Entra identities, Key Vault secrets, app credentials.
4. Verify controls:
   - Policy compliance, Defender recommendations, alert health, logging coverage.
5. Conduct customer impact verification with product and support teams.

Exit criteria:
- No active attacker foothold indicators.
- Business services stable.
- Monitoring and detections tuned for recurrence.

## 14. Phase 6: Post-Incident Activities
Within 5 business days:
1. Run blameless post-incident review.
2. Document:
   - Root cause
   - Timeline
   - Impact
   - What worked / failed
   - Action items with owners and due dates
3. Update:
   - Detection rules
   - IaC guardrails/policies
   - SOC runbooks and automation rules
4. Report KPI:
   - MTTA, MTTR, dwell time, recurrence risk.

## 15. Communications and Notification
- Internal:
  - SOC -> IC -> Executives for Sev1/Sev2
  - Legal/Privacy engaged immediately if regulated data risk exists
- External:
  - Customer/regulator notifications only via Legal/Privacy approved process
  - Preserve factual language; avoid unverified attribution

## 16. Evidence Handling Requirements
- Maintain chain-of-custody log:
  - Who collected what, when, from where, hash if applicable
- Keep all timestamps in UTC
- Do not delete forensic data during active investigation
- Store incident artifacts in restricted, immutable location when possible

## 17. SOC Analyst Quick Checklist (Printable)
1. Confirm incident and set severity.
2. Notify IC and required stakeholders.
3. Preserve evidence (alerts, logs, entities, timeline).
4. Scope identities, workloads, and data.
5. Execute approved containment.
6. Validate containment effectiveness.
7. Support eradication and recovery tasks.
8. Record every action in incident timeline.
9. Participate in post-incident review.

## 18. Minimum Automation Recommendations (Sentinel/Defender)
- Automation rules:
  - Auto-tag and assign incidents by source/type.
  - Trigger playbook for Sev1 identity compromise.
- Playbook actions (Logic Apps):
  - Notify on-call + incident channel
  - Open ticket with mandatory fields
  - Execute conditional account disable (with approval gate)
- Defender for Cloud workflow automation:
  - Route high-confidence alerts to incident channel and ticketing.

## 19. Azure SaaS-Specific Hardening Follow-Ups After Any Breach
- Revalidate Key Vault private endpoint + RBAC only model.
- Confirm Container Apps ingress and revision policy settings.
- Verify no public network exposure drift in PaaS services.
- Re-run IaC validation/security assertions and policy compliance.
- Enforce branch protections and CI/CD OIDC restrictions.

## 20. References (Official Guidance)
- NIST SP 800-61 Rev. 3 announcement and supersession details:
  - https://www.nist.gov/news-events/news/2025/04/nist-revises-sp-800-61-incident-response-recommendations-and-considerations
- NIST SP 800-61 Rev. 2 publication record (superseded by Rev. 3):
  - https://csrc.nist.gov/pubs/sp/800/61/r2/final
- Azure incident response overview:
  - https://learn.microsoft.com/en-us/azure/security/fundamentals/incident-response-overview
- Microsoft Security incident response overview:
  - https://learn.microsoft.com/en-us/security/operations/incident-response-overview
- Microsoft Security incident response playbooks:
  - https://learn.microsoft.com/en-us/security/operations/incident-response-playbooks
- Microsoft Sentinel automation rules:
  - https://learn.microsoft.com/en-us/azure/sentinel/automate-incident-handling-with-automation-rules
- Microsoft Sentinel playbooks:
  - https://learn.microsoft.com/en-us/azure/sentinel/automation/run-playbooks
- Defender for Cloud workflow automation:
  - https://learn.microsoft.com/en-us/azure/defender-for-cloud/workflow-automation
- Key Vault soft-delete and purge protection:
  - https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-change
- Key Vault recovery:
  - https://learn.microsoft.com/en-us/azure/key-vault/general/key-vault-recovery
- Container Apps revision management (rollback operations):
  - https://learn.microsoft.com/en-us/azure/container-apps/revisions-manage

