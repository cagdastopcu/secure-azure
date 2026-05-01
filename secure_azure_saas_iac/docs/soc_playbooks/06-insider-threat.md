# Playbook: Insider Threat

## Triggers
- Unusual privileged actions by known employee/contractor
- Data access inconsistent with job function
- Attempts to bypass approvals or disable monitoring

## Immediate Actions (0-30 min)
1. Notify SOC lead and Legal/HR confidentially.
2. Preserve evidence and avoid tipping-off subject.
3. Apply minimum required access restrictions.

## Investigation
1. Build activity timeline (identity, data, admin actions).
2. Validate business justification with manager/data owner.
3. Determine malicious intent vs negligence.

## Containment/Eradication
1. Remove excess privileges and unauthorized access paths.
2. Rotate affected secrets/keys if exposure suspected.
3. Coordinate HR/legal disciplinary or legal action workflow.

## Recovery
1. Confirm no remaining unauthorized access.
2. Improve segregation of duties and approval controls.
3. Add detections for repeated behavior patterns.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Preserve confidential handling and evidence integrity; restrict case visibility on need-to-know basis.
- Require Legal/HR coordination before subject-facing actions.
- Close only after corrective access model and monitoring controls are validated.

## Official References
- Defender incident management:
  - https://learn.microsoft.com/en-us/microsoft-365/security/defender/manage-incidents
- Microsoft incident response overview:
  - https://learn.microsoft.com/en-us/security/operations/incident-response-overview
