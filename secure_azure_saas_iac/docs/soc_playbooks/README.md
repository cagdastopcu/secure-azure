# SOC Playbooks Catalog

This folder contains operational playbooks for the Azure SaaS SOC program.

## Standards
- `00-soc-operating-standard.md` - Shared triage, evidence, approval, communication, and closure rules

## Core
- `SOC_BREACH_PLAYBOOK.md` - End-to-end breach response baseline (NIST-aligned lifecycle)

## Scenario Playbooks
- `01-identity-compromise.md`
- `02-cicd-supply-chain.md`
- `03-container-runtime-compromise.md`
- `04-data-exfiltration.md`
- `05-ransomware-destructive.md`
- `06-insider-threat.md`
- `07-third-party-vendor-breach.md`
- `08-customer-tenant-impact.md`
- `09-cloud-misconfiguration-exposure.md`
- `10-post-incident-hardening.md`
- `11-kql-starter-queries.md`

## Common Expectations
- Use UTC timestamps in all timelines.
- Maintain chain of custody for all evidence.
- Use one incident record as source of truth.
- Track MTTA, MTTR, and key decision timestamps.
- Work from the Microsoft Defender portal incident queue as primary SOC workflow.

## Official Reference Set
- NIST SP 800-61r3 publication record:
  - https://www.nist.gov/publications/incident-response-recommendations-and-considerations-cybersecurity-risk-management-csf
- NIST announcement for SP 800-61r3 (supersedes r2):
  - https://www.nist.gov/news-events/news/2025/04/nist-revises-sp-800-61-incident-response-recommendations-and-considerations
- CISA Cybersecurity Incident and Vulnerability Response Playbooks:
  - https://www.cisa.gov/resources-tools/resources/federal-government-cybersecurity-incident-and-vulnerability-response-playbooks
- Azure incident response overview:
  - https://learn.microsoft.com/en-us/azure/security/fundamentals/incident-response-overview
- Microsoft Defender incident response workflow:
  - https://learn.microsoft.com/en-us/unified-secops/plan-incident-response
- Sentinel automation rules and playbooks:
  - https://learn.microsoft.com/en-us/azure/sentinel/automate-incident-handling-with-automation-rules
  - https://learn.microsoft.com/en-us/azure/sentinel/automation/automation
