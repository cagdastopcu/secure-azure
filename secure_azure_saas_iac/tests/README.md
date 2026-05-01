# Tests for Secure Azure SaaS IaC

This folder contains lightweight, practical checks for IaC quality and security posture.

## Structure
- `scripts/validate-iac.ps1`: compiles all Bicep files to catch syntax/resource-schema issues early
- `scripts/assert-security.ps1`: checks key hardened defaults in source templates
- `smoke/`: place environment-specific validate/what-if scripts here
- `policy/`: place policy compliance test scripts here

## Local Run
```powershell
pwsh -File .\secure_azure_saas_iac\tests\scripts\validate-iac.ps1
pwsh -File .\secure_azure_saas_iac\tests\scripts\assert-security.ps1
```

## CI Behavior
The GitHub workflow runs these scripts in the `static-tests` job before/alongside deployment validation.
