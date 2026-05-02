# -----------------------------------------------------------------------------
# GLOSSARY + SAAS CONTEXT (DEEP PLAIN-LANGUAGE)
# - IaC: This file defines cloud behavior as auditable text instead of manual clicks.
# - Module: Reusable building block with inputs (parameters) and outputs.
# - Parameter: Value you change per environment without rewriting deployment logic.
# - Resource: Actual Azure service instance created by this file.
# - Output: Exported value used by other modules, tests, or pipeline steps.
# - Identity-first: Prefer managed identities over embedded static credentials.
# - Private-first: Prefer private networking and explicit ingress boundaries.
# - How this file is used in this SaaS project:
#   1. Compiles all Bicep templates in CI.
#   2. Used to fail fast on syntax/type/template errors.
#   3. Inputs: IaC root path override.
#   4. Outputs: build logs and script exit status.
#   5. Security role: blocks broken infrastructure changes before deploy.
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




