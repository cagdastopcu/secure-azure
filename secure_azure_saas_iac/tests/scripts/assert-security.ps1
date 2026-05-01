# -----------------------------------------------------------------------------
# TERM GLOSSARY (this script)
# - Param block: Declares script input parameters.
# - Function: Reusable block of script logic.
# - Throw: Stops execution with explicit error.
# - ErrorActionPreference=Stop: Fail fast on errors.
# - Assert: Check expected condition and fail if missing.
# -----------------------------------------------------------------------------
# What: start script parameters. Why: caller can pass custom values.
param(
  # What: script input value. Why: configurable path/option.
  [string]$IaCRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
# What/Why: this line is part of script control flow or value assignment.
)

# What: stop-on-error mode. Why: fail immediately in CI.
$ErrorActionPreference = 'Stop'

# What: helper function definition. Why: reusable logic block.
function Assert-Contains {
  # What: start script parameters. Why: caller can pass custom values.
  param(
    # What: script input value. Why: configurable path/option.
    [string]$Path,
    # What: script input value. Why: configurable path/option.
    [string]$Pattern,
    # What: script input value. Why: configurable path/option.
    [string]$Message
  # What/Why: this line is part of script control flow or value assignment.
  )

  # What/Why: this line is part of script control flow or value assignment.
  $content = Get-Content -LiteralPath $Path -Raw
  # What: condition check. Why: branch based on pass/fail state.
  if ($content -notmatch $Pattern) {
    # What: explicit failure. Why: stop pipeline when requirement is missing.
    throw "[assert-security] FAIL: $Message`n  File: $Path`n  Pattern: $Pattern"
  # What: close code block. Why: end current scope.
  }

  # What: log output. Why: show progress/results in CI logs.
  Write-Host "[assert-security] PASS: $Message"
# What: close code block. Why: end current scope.
}

# What/Why: this line is part of script control flow or value assignment.
$stamp = Join-Path $IaCRoot 'stamps\aca-stamp\main.bicep'
# What/Why: this line is part of script control flow or value assignment.
$rootMain = Join-Path $IaCRoot 'main.bicep'

# What: assertion call. Why: enforce required security baseline setting.
Assert-Contains -Path $rootMain -Pattern "param\s+enablePublicWebIngress\s+bool\s*=\s*false" -Message 'Public web ingress defaults to disabled.'
# What: assertion call. Why: enforce required security baseline setting.
Assert-Contains -Path $stamp -Pattern "publicNetworkAccess:\s*'Disabled'" -Message 'Key Vault public network access is disabled.'
# What: assertion call. Why: enforce required security baseline setting.
Assert-Contains -Path $stamp -Pattern "allowInsecure:\s*false" -Message 'Container Apps ingress disallows insecure HTTP.'
# What: assertion call. Why: enforce required security baseline setting.
Assert-Contains -Path $stamp -Pattern "external:\s*false" -Message 'At least one app (worker) is internal-only.'
# What: assertion call. Why: enforce required security baseline setting.
Assert-Contains -Path $stamp -Pattern "resource\s+kvPrivateDnsZone\s+'Microsoft.Network/privateDnsZones@" -Message 'Private DNS zone for Key Vault private endpoint exists.'

# What: log output. Why: show progress/results in CI logs.
Write-Host '[assert-security] Success: security baseline assertions passed.'




