# Playbook: Container Runtime Compromise (Azure Container Apps)

## Triggers
- New revision created outside change window
- Suspicious outbound traffic or command execution
- Runtime alert for cryptomining/web shell behavior

## Immediate Actions (0-30 min)
1. Route traffic away from suspicious revision.
2. Deactivate malicious revision and keep evidence.
3. Restrict workload identity permissions immediately.

## Investigation
1. Compare revision spec deltas (image, env vars, secrets, scale).
2. Validate image digest against approved registry provenance.
3. Review logs for command-and-control, lateral movement, and data access.

## Containment/Eradication
1. Remove compromised image/artifacts from promotion path.
2. Rotate app secrets and credentials.
3. Patch vulnerable base image/dependency and redeploy.

## Recovery
1. Activate known-good revision and verify health.
2. Enable enhanced detections for same behavior pattern.
3. Document root cause in backlog with owner and due date.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Preserve revision IDs, image digests, ingress/traffic state, and workload identity changes.
- Require IC approval before traffic cutover actions affecting all tenants.
- Close only after clean revision verification and secret rotation are confirmed.

## Official References
- Container Apps revision management:
  - https://learn.microsoft.com/en-us/azure/container-apps/revisions-manage
- Azure incident response overview:
  - https://learn.microsoft.com/en-us/azure/security/fundamentals/incident-response-overview
