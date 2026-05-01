# Playbook: Data Exfiltration

## Triggers
- Unusual SQL exports / query volume spikes
- Storage egress anomalies or abnormal object reads
- Key Vault secret access burst by unusual principal

## Immediate Actions (0-30 min)
1. Isolate suspicious identity/workload.
2. Restrict network egress and suspicious endpoint paths.
3. Escalate to Legal/Privacy for potential regulated data impact.

## Investigation
1. Determine data type, sensitivity, tenant scope, and time window.
2. Quantify potential records/files/objects accessed or exported.
3. Correlate identity, workload, and control-plane events.

## Containment/Eradication
1. Block attacker path (identity, app, API key, route).
2. Rotate exposed credentials/secrets/keys.
3. Remove persistence and unauthorized data channels.

## Recovery
1. Validate data integrity and restore if tampering occurred.
2. Trigger customer notification workflow if required by law/contract.
3. Add permanent detections for data access anomalies.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Preserve query/access logs, object access trails, IP/device/user mappings, and export job artifacts.
- Require Legal/Privacy approval before external disclosure.
- Close only after impact quantification and remediation communication plan are complete.

## Official References
- Azure SQL restore guidance:
  - https://learn.microsoft.com/azure/azure-sql/database/recovery-using-backups?tabs=azure-portal&view=azuresql
- Defender portal incident response:
  - https://learn.microsoft.com/en-us/security/zero-trust/respond-incident
