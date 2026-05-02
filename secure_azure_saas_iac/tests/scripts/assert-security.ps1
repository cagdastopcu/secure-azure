# -----------------------------------------------------------------------------
# FILE: CI script that asserts required security defaults in IaC text.
# USED IN SAAS FLOW: Detects security baseline regressions during review.
# SECURITY-CRITICAL: Blocks merges that weaken private-first or TLS controls.
# -----------------------------------------------------------------------------
param(
  # Root folder of the IaC project; defaults to two levels above this script.
  [string]$IaCRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

# Fail fast to ensure any missing hardening control breaks CI.
$ErrorActionPreference = 'Stop'

# Helper that asserts a regex pattern exists in a target file.
function Assert-Contains {
  param(
    # File path to inspect.
    [string]$Path,
    # Regex pattern representing the required security control.
    [string]$Pattern,
    # Human-readable assertion name shown in test output.
    [string]$Message
  )

  $content = Get-Content -LiteralPath $Path -Raw
  if ($content -notmatch $Pattern) {
    throw "[assert-security] FAIL: $Message`n  File: $Path`n  Pattern: $Pattern"
  }

  Write-Host "[assert-security] PASS: $Message"
}

# Key files checked by this policy test.
$stamp = Join-Path $IaCRoot 'stamps\aca-stamp\main.bicep'
$dataStamp = Join-Path $IaCRoot 'stamps\data-stamp\main.bicep'
$network = Join-Path $IaCRoot 'platform\network\main.bicep'
$rootMain = Join-Path $IaCRoot 'main.bicep'

# Public ingress defaults to private-first model.
Assert-Contains -Path $rootMain -Pattern "param\s+enablePublicWebIngress\s+bool\s*=\s*false" -Message 'Public web ingress defaults to disabled.'
# Key Vault must not expose a public endpoint.
Assert-Contains -Path $stamp -Pattern "publicNetworkAccess:\s*'Disabled'" -Message 'Key Vault public network access is disabled.'
# Insecure HTTP must be disabled on app ingress.
Assert-Contains -Path $stamp -Pattern "allowInsecure:\s*false" -Message 'Container Apps ingress disallows insecure HTTP.'
# At least one workload is internal-only to enforce private service pattern.
Assert-Contains -Path $stamp -Pattern "external:\s*false" -Message 'At least one app (worker) is internal-only.'
# Private DNS zone is required for Key Vault private endpoint resolution.
Assert-Contains -Path $stamp -Pattern "resource\s+kvPrivateDnsZone\s+'Microsoft.Network/privateDnsZones@" -Message 'Private DNS zone for Key Vault private endpoint exists.'
# Firewall checks ensure the platform can enforce inspected outbound paths when required.
Assert-Contains -Path $network -Pattern "param\s+enableAzureFirewallForEgress\s+bool\s*=\s*false" -Message 'Azure Firewall egress control is optional and off by default.'
# Deny is tested as default so known-malicious destinations are blocked by default posture.
Assert-Contains -Path $network -Pattern "param\s+azureFirewallThreatIntelMode\s+string\s*=\s*'Deny'" -Message 'Azure Firewall threat intel mode defaults to Deny.'
# SQL retention policy resources are required for operational and compliance restore objectives.
Assert-Contains -Path $dataStamp -Pattern "backupShortTermRetentionPolicies@" -Message 'SQL short-term backup retention policy resource exists.'
Assert-Contains -Path $dataStamp -Pattern "backupLongTermRetentionPolicies@" -Message 'SQL long-term backup retention policy resource exists.'
# Backup redundancy parameter must exist to support cross-zone/cross-region restore strategies.
Assert-Contains -Path $dataStamp -Pattern "param\s+sqlBackupStorageRedundancy\s+string\s*=\s*'Geo'" -Message 'SQL backup storage redundancy defaults to Geo.'

Write-Host '[assert-security] Success: security baseline assertions passed.'




