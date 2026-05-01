# Playbook: Ransomware or Destructive Attack

## Triggers
- Mass encryption/deletion behavior
- Spike in destructive API calls
- Simultaneous service outage + extortion note

## Immediate Actions (0-30 min)
1. Declare Sev1 and assign Incident Commander.
2. Isolate compromised identities and workloads.
3. Freeze non-IR changes and preserve forensic evidence.

## Investigation
1. Identify blast radius across compute, data, identity, and CI/CD.
2. Confirm backup health and latest safe restore points.
3. Detect attacker persistence and command channels.

## Containment/Eradication
1. Remove attacker access paths and persistence.
2. Rotate all high-risk credentials.
3. Enforce emergency network restrictions.

## Recovery
1. Restore critical services in dependency order.
2. Use point-in-time restore where needed (SQL/data services).
3. Validate business integrity before full traffic restoration.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Preserve destructive action evidence before rollback wherever feasible.
- Require IC + Executive approval for broad shutdown decisions.
- Close only after restore validation and post-incident hardening plan are approved.

## Official References
- CISA incident response playbooks (coordination model):
  - https://www.cisa.gov/sites/default/files/2024-08/Federal_Government_Cybersecurity_Incident_and_Vulnerability_Response_Playbooks_508C.pdf
- NIST SP 800-61r3 publication:
  - https://www.nist.gov/publications/incident-response-recommendations-and-considerations-cybersecurity-risk-management-csf
