# Playbook: Post-Incident Hardening

## Trigger
- Any confirmed Sev1/Sev2 incident closure

## Goals
- Prevent recurrence
- Reduce MTTA/MTTR in similar future incidents
- Convert lessons learned to enforced controls

## Mandatory Actions (within 10 business days)
1. Complete root cause and contributing-factor analysis.
2. Convert findings to tracked tasks with owner and due date.
3. Update detections (Sentinel/Defender/KQL) for missed signals.
4. Update IaC controls and policy assignments for gaps.
5. Validate backup/restore and rollback runbooks if used.
6. Update SOC playbooks and communication templates.

## Technical Hardening Checklist
1. Identity:
   - Least privilege cleanup, MFA/CA tightening, stale principal removal.
2. Workload:
   - Image pinning/provenance, secure revision management, secrets rotation.
3. Data:
   - Access anomaly detection, stricter network isolation, key rotation.
4. CI/CD:
   - OIDC trust scope minimization, protected environments, workflow approvals.
5. Governance:
   - Policy-as-code updates, drift detection, continuous compliance checks.

## Closure Criteria
- All Sev1 actions completed or risk-accepted by leadership.
- KPI report delivered (MTTA, MTTR, dwell time, recurrence risk).
- Playbooks, automation, and controls updated and validated.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Track every hardening action with owner, due date, and verification evidence.
- Include one preventive control, one detective control, and one response control improvement at minimum.

## Official References
- NIST SP 800-61r3 publication:
  - https://www.nist.gov/publications/incident-response-recommendations-and-considerations-cybersecurity-risk-management-csf
- Sentinel automation best practices:
  - https://learn.microsoft.com/en-us/azure/sentinel/automate-incident-handling-with-automation-rules
