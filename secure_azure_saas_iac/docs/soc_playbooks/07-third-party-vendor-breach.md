# Playbook: Third-Party or Vendor Breach Impact

## Triggers
- Vendor security advisory affecting your dependencies
- Cloud platform incident notice with potential tenant impact
- Threat intel indicating compromised supplier package/action

## Immediate Actions (0-30 min)
1. Classify exposure: direct, indirect, or unaffected.
2. Freeze upgrades/deployments involving affected dependency.
3. Start stakeholder communication thread (Security, Platform, Legal).

## Investigation
1. Map affected vendor components to your services.
2. Identify where compromised versions/artifacts are running.
3. Assess data exposure and integrity risk.

## Containment/Eradication
1. Block/replace compromised dependencies immediately.
2. Rebuild and redeploy from clean sources.
3. Revoke any keys/tokens shared with affected vendor integration.

## Recovery
1. Validate with vendor remediation guidance.
2. Keep temporary detections active for related IOCs.
3. Update supplier risk and SBOM/process controls.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Preserve advisory timeline, affected versions, and internal exposure mapping.
- Require Security leadership approval before production dependency re-enable.
- Close only after supplier controls and dependency scanning updates are complete.

## Official References
- CISA incident/vulnerability response playbooks:
  - https://www.cisa.gov/sites/default/files/2024-08/Federal_Government_Cybersecurity_Incident_and_Vulnerability_Response_Playbooks_508C.pdf
- Azure Well-Architected operational incident strategy:
  - https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/incident-response
