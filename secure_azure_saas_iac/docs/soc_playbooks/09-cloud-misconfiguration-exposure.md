# Playbook: Cloud Misconfiguration Exposure

## Triggers
- Public access accidentally enabled on private service
- NSG/Firewall/Policy drift alerts
- Defender for Cloud recommendation indicates critical exposure

## Immediate Actions (0-30 min)
1. Remove public exposure immediately (deny-by-default).
2. Snapshot current config state for evidence.
3. Confirm if exposure was externally reachable.

## Investigation
1. Identify root cause (manual change, IaC drift, pipeline bypass).
2. Determine exposure window and potentially accessed assets.
3. Validate if attacker activity occurred during exposure window.

## Containment/Eradication
1. Reapply secure IaC baseline and policies.
2. Lock mutation path (permissions, approvals, branch protections).
3. Add drift detection/auto-remediation controls.

## Recovery
1. Verify configuration compliance across all environments.
2. Run focused threat hunt for exposure-related activity.
3. Document prevention actions in hardening backlog.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Preserve pre-fix and post-fix configuration state for audit.
- Require Platform/Security approval before emergency policy overrides.
- Close only after policy compliance and drift detection are revalidated.

## Official References
- Azure incident response overview:
  - https://learn.microsoft.com/en-us/azure/security/fundamentals/incident-response-overview
- Defender for Cloud workflow automation:
  - https://learn.microsoft.com/en-us/azure/defender-for-cloud/workflow-automation
