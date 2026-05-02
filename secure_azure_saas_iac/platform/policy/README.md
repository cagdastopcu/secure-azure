# Policy Baseline

This folder contains governance-as-code modules for Azure Policy.
These modules enforce platform guardrails so teams cannot drift into insecure or non-compliant configurations.

## Concepts (Plain Language)

- `Policy Definition`: The rule logic itself (for example "resource must be in allowed region").
- `Policy Assignment`: Applying that rule to a scope (management group, subscription, or resource group).
- `Policy Effect`: What happens when rule matches (`Deny`, `Audit`, `Modify`, etc.).
- `Scope`: Where policy is enforced.
- `Initiative`: A bundle of policy definitions assigned together.

## Files in This Folder

### `security-baseline.bicep`

Purpose:
- Deploys baseline policy assignments for foundational governance.

Current controls:
- Allowed locations
- Required tags and expected values:
  - `environment`
  - `project`
  - `managedBy`

Why it matters:
- Enforces consistent deployment region strategy.
- Prevents untagged resources that break ownership, cost, and incident accountability.

### `public-network-deny.bicep`

Purpose:
- Optional stronger guardrails to deny public network exposure for selected services.

Why it matters:
- Converts "best practice" into enforcement.
- Reduces risk of accidental internet exposure for data and secret services.

### `*.json` files

These are generated ARM JSON artifacts that correspond to Bicep templates.
They are useful for troubleshooting and compatibility workflows that require ARM JSON.

## How This Connects to Root Deployment

`main.bicep` invokes:
- `security-baseline.bicep` by default
- `public-network-deny.bicep` only when explicitly enabled

This creates a progressive governance model:
- baseline always on
- strict deny controls opt-in by environment maturity

## Operational Notes

- Keep policy assignment scopes aligned with your landing zone model.
- Prefer assignment at higher scope (management group/subscription) for consistent enforcement.
- If your organization uses custom initiatives, swap built-in definition IDs with your standard IDs.
