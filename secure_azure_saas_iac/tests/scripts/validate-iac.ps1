# -----------------------------------------------------------------------------
# GLOSSARY + SAAS CONTEXT
# - IaC: Infrastructure as Code; cloud resources are defined as versioned text files.
# - Module: Reusable deployment unit with parameters and outputs.
# - Parameter: Input value used to customize deployment per SaaS environment.
# - Resource: Azure object created by this file.
# - Output: Value exported for other modules/tests/pipelines.
# - Least privilege: Grant identities only permissions they strictly need.
# - Private endpoint: Private IP path to PaaS service to reduce public attack surface.
# - Diagnostics: Logs/metrics sent to central monitoring for operations and incident response.
# - SaaS use here: Compiles all Bicep files so SaaS IaC errors are detected before deployment.
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




