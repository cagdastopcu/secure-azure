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

# Azure CLI is required because this script uses `az bicep build`.
Require-Command -Name 'az'

Write-Host "[validate-iac] Installing/updating Bicep CLI via Azure CLI..."
az bicep install | Out-Null

# Build all Bicep files recursively so module-level errors are caught early.
$bicepFiles = Get-ChildItem -Path $IaCRoot -Recurse -Filter '*.bicep' -File
if (-not $bicepFiles) {
  throw 'No .bicep files found to validate.'
}

foreach ($file in $bicepFiles) {
  Write-Host "[validate-iac] Building: $($file.FullName)"
  # Compile each file independently; this catches syntax, type, and module-reference errors.
  az bicep build --file $file.FullName | Out-Null
}

Write-Host "[validate-iac] Success: all Bicep files compiled."




