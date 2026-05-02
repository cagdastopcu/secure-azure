# Tests for Secure Azure SaaS IaC

This folder provides executable quality gates for this IaC project.
The purpose is to fail early when a change breaks deployments or weakens security defaults.

## What Exists Today

- `scripts/validate-iac.ps1`
  - Builds every `.bicep` file under the IaC root.
  - Catches syntax errors, invalid references, and type issues before deployment.
  - Resolves Azure CLI path robustly on Windows (uses fallback path if `az` is not in `PATH`).

- `scripts/assert-security.ps1`
  - Uses pattern assertions on source files for critical controls.
  - Ensures baseline security defaults remain present.
  - Example checks:
    - public ingress default is disabled
    - Key Vault public network access is disabled
    - firewall egress toggle exists and defaults safe
    - SQL backup retention resources exist

- `smoke/`
  - Reserved for environment smoke scripts (deploy + health checks).

- `policy/`
  - Reserved for policy-compliance validation scripts.

## Why Two Scripts Instead of One

- `validate-iac.ps1` answers: "Can this code compile?"
- `assert-security.ps1` answers: "Did we accidentally remove required hardening?"

Both are needed:
- Compile success does not guarantee secure defaults.
- Security patterns can pass while code still fails to build.

## Run Locally

```powershell
pwsh -File .\secure_azure_saas_iac\tests\scripts\validate-iac.ps1 -IaCRoot .\secure_azure_saas_iac
pwsh -File .\secure_azure_saas_iac\tests\scripts\assert-security.ps1 -IaCRoot .\secure_azure_saas_iac
```

## How to Interpret Output

- `PASS` in `assert-security.ps1`: expected secure baseline controls were found.
- `FAIL` in `assert-security.ps1`: required control is missing from code.
- `Success: all Bicep files compiled`: all templates built successfully.
- `WARNING` lines from Bicep:
  - non-blocking unless you choose to enforce warning-free policy.
  - still important for cleanup backlog.

## CI Usage

Run both scripts in pull request validation before any environment deployment step.
Recommended order:
1. `validate-iac.ps1`
2. `assert-security.ps1`
3. optional `what-if`
4. deploy

This prevents broken or weakened IaC from progressing to runtime environments.
