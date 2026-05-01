# Playbook: Customer/Tenant Impact Management

## Triggers
- Confirmed breach with potential multi-tenant exposure
- Customer-reported suspicious access to tenant data
- Data exfiltration event with tenant ambiguity

## Immediate Actions (0-30 min)
1. Start tenant impact matrix (tenant, data type, impact confidence).
2. Lock down affected access path.
3. Escalate to Legal/Privacy and Customer Success leadership.

## Investigation
1. Determine exactly which tenants were affected and when.
2. Quantify impacted records and sensitivity per tenant.
3. Validate integrity (read vs modify vs delete impact).

## Containment/Eradication
1. Isolate impacted tenant pathways if possible.
2. Rotate tenant-scoped keys/secrets/tokens.
3. Apply compensating controls for unaffected tenants.

## Recovery
1. Execute tenant communication plan (approved templates only).
2. Provide customer-facing timeline and remediation summary.
3. Track tenant-specific follow-up actions to closure.

## Operational Requirements
- Apply baseline process in `00-soc-operating-standard.md`.
- Maintain tenant-level impact matrix with confidence level and evidence links.
- Require Legal/Privacy approval for customer/regulator statements.
- Close only after all impacted tenants receive approved remediation updates.

## Official References
- Defender portal incident response process:
  - https://learn.microsoft.com/en-us/security/zero-trust/respond-incident
- NIST SP 800-61r3 publication:
  - https://www.nist.gov/publications/incident-response-recommendations-and-considerations-cybersecurity-risk-management-csf
