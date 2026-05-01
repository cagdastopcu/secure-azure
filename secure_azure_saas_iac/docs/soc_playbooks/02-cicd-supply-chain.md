# Playbook: CI/CD Supply Chain Compromise

## Triggers
- Unexpected GitHub workflow changes
- Suspicious OIDC federation usage
- Deployment of unapproved image digest/tag

## Immediate Actions (0-30 min)
1. Pause impacted pipelines and deployment environments.
2. Disable compromised repository/workflow permissions.
3. Freeze production changes except emergency IR actions.

## Investigation
1. Review GitHub audit logs, workflow runs, actor identities, and commit provenance.
2. Identify unauthorized artifact creation or promotion.
3. Check Azure actions executed by federated identity.

## Containment/Eradication
1. Rotate trust relationships (OIDC subject filters, environment protections).
2. Revoke unauthorized tokens/credentials.
3. Remove malicious workflows, actions, or runners.

## Recovery
1. Redeploy from trusted commit + trusted image digest.
2. Enforce branch protection and required reviews.
3. Add alerting for workflow file changes and privileged pipeline actions.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Preserve workflow run IDs, commit SHAs, actor IDs, OIDC claims, and deployment logs.
- Require Incident Commander and Platform approval before global pipeline shutdown.
- Close only after trust policy hardening and clean redeploy validation are complete.

## Official References
- Azure Well-Architected incident management strategy:
  - https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/incident-response
- Microsoft Defender incident workflow:
  - https://learn.microsoft.com/en-us/unified-secops/plan-incident-response
