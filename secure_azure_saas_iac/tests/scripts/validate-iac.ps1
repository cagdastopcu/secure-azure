# -----------------------------------------------------------------------------
# FILE: CI validation script for Bicep compilation.
# USED IN SAAS FLOW: Fails pull requests when templates are invalid.
# SECURITY-CRITICAL: Prevents broken or unsafe infrastructure changes from advancing.
# -----------------------------------------------------------------------------
param(
  # Root folder of the IaC project; defaults to two levels above this script.
  [string]$IaCRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

# Fail fast in CI so broken templates stop the pipeline immediately.
$ErrorActionPreference = 'Stop'

# Guard: require external command before using it.
function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

# Resolve Azure CLI command path robustly for shells where PATH doesn't include az.
$azCommand = Get-Command az -ErrorAction SilentlyContinue
if (-not $azCommand) {
  # Fallback path for standard Windows Azure CLI installer location.
  $azFallbackPath = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
  if (Test-Path $azFallbackPath) {
    # Normalize into object shape with Source property so later invocation stays identical.
    $azCommand = @{
      Source = $azFallbackPath
    }
  }
}
if (-not $azCommand) {
  # Hard fail ensures CI does not silently skip template compilation checks.
  throw 'Required command not found: az (and fallback path not found).'
}

Write-Host "[validate-iac] Installing/updating Bicep CLI via Azure CLI..."
& $azCommand.Source bicep install | Out-Null

# Build all Bicep files recursively so module-level errors are caught early.
$bicepFiles = Get-ChildItem -Path $IaCRoot -Recurse -Filter '*.bicep' -File
if (-not $bicepFiles) {
  throw 'No .bicep files found to validate.'
}

foreach ($file in $bicepFiles) {
  Write-Host "[validate-iac] Building: $($file.FullName)"
  # Compile each file independently; this catches syntax, type, and module-reference errors.
  & $azCommand.Source bicep build --file $file.FullName | Out-Null
}

Write-Host "[validate-iac] Success: all Bicep files compiled."




