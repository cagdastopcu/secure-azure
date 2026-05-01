# Playbook: Identity Compromise

## Triggers
- Impossible travel / risky sign-in alerts
- MFA fatigue or unusual token issuance
- Privileged role assignment anomaly

## Immediate Actions (0-30 min)
1. Disable affected account(s) or block sign-in.
2. Revoke active sessions/tokens.
3. Remove newly added privileged roles and suspicious app consents.
4. Elevate severity to Sev1 if admin identity is impacted.

## Investigation
1. Build timeline of sign-ins, conditional access results, and role changes.
2. Identify lateral movement via service principals and workload identities.
3. Validate affected resources (Key Vault, SQL, Storage, Container Apps).

## Containment/Eradication
1. Rotate credentials and secrets used by impacted principals.
2. Enforce strong MFA and conditional access corrections.
3. Remove malicious OAuth grants / federated credentials.

## Recovery
1. Restore least-privilege RBAC.
2. Re-enable account only after clean bill of health.
3. Increase temporary monitoring for repeated TTPs.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Preserve Entra sign-in logs, audit logs, token/session evidence, and RBAC change records in UTC.
- Require Incident Commander approval before disabling shared production service identities.
- Close only after forced password reset/MFA hardening and role review are complete.

## Official References
- Microsoft incident response workflow:
  - https://learn.microsoft.com/en-us/unified-secops/plan-incident-response
- Microsoft incident response playbooks:
  - https://learn.microsoft.com/en-us/security/operations/incident-response-playbooks
