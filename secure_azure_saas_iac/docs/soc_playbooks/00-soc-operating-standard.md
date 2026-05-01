# SOC Operating Standard (Applies to All Playbooks)

## 1. Incident Lifecycle Model
Use this lifecycle for every incident:
1. Preparation
2. Detection and analysis
3. Containment
4. Eradication
5. Recovery
6. Post-incident learning

This aligns with NIST SP 800-61r3 and Azure incident response guidance.

## 2. Severity and Escalation
- `Sev1`: Confirmed active breach, high business impact, possible/confirmed sensitive data impact.
  - IC assigned immediately.
  - Executive + Legal/Privacy notification target: <= 30 minutes.
- `Sev2`: Confirmed compromise with limited or unclear data impact.
  - IC assigned within 30 minutes.
- `Sev3`: Suspicious behavior requiring deeper investigation.

## 3. Mandatory Evidence Handling
For every incident, capture:
- Incident ID, alert IDs, source systems
- Exact UTC timeline of all actions
- Affected identities, resources, tenant IDs, subscription IDs
- Analyst notes explaining decisions and confidence level

Rules:
- Never delete volatile evidence during active incident.
- Maintain chain of custody (collector, timestamp, location, checksum when applicable).
- Use a single source-of-truth incident record.

## 4. Approval Gates
Require Incident Commander approval before:
- Disabling production identity used by critical services
- Blocking internet ingress broadly
- Disabling pipelines/environments in production
- Initiating customer-impacting recovery actions

Require Legal/Privacy approval before:
- Customer notification content
- Regulator notification content
- Attribution statements

## 5. Communications Protocol
- Internal updates:
  - Sev1: every 30 minutes
  - Sev2: hourly
- Updates must include:
  - What changed
  - Current impact
  - Next action and owner
  - Risks/blockers

## 6. Closure Criteria (Minimum)
An incident is not closed until:
1. Containment and eradication are verified.
2. Recovery validation is complete.
3. Detections and guardrails are updated.
4. Post-incident report is drafted with owners and due dates.

## 7. Automation Baseline
- Use Sentinel automation rules to auto-tag/assign/escalate incidents.
- Use playbooks (Logic Apps) for repeatable safe actions.
- Keep manual approval for destructive/high-impact actions.

## 8. Official References
- NIST SP 800-61r3:
  - https://www.nist.gov/publications/incident-response-recommendations-and-considerations-cybersecurity-risk-management-csf
- NIST announcement (r3 supersedes r2):
  - https://www.nist.gov/news-events/news/2025/04/nist-revises-sp-800-61-incident-response-recommendations-and-considerations
- CISA playbooks (PDF):
  - https://www.cisa.gov/sites/default/files/2024-08/Federal_Government_Cybersecurity_Incident_and_Vulnerability_Response_Playbooks_508C.pdf
- Azure incident response overview:
  - https://learn.microsoft.com/en-us/azure/security/fundamentals/incident-response-overview
- Defender incident workflow:
  - https://learn.microsoft.com/en-us/unified-secops/plan-incident-response
