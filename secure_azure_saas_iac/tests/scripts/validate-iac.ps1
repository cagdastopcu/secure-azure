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
function Require-Command {
  # What: start script parameters. Why: caller can pass custom values.
  param([string]$Name)
  # What: condition check. Why: branch based on pass/fail state.
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    # What: explicit failure. Why: stop pipeline when requirement is missing.
    throw "Required command not found: $Name"
  # What: close code block. Why: end current scope.
  }
# What: close code block. Why: end current scope.
}

# What/Why: this line is part of script control flow or value assignment.
Require-Command -Name 'az'

# What: log output. Why: show progress/results in CI logs.
Write-Host "[validate-iac] Installing/updating Bicep CLI via Azure CLI..."
# What: Azure CLI command. Why: compile/validate templates.
az bicep install | Out-Null

# What/Why: this line is part of script control flow or value assignment.
$bicepFiles = Get-ChildItem -Path $IaCRoot -Recurse -Filter '*.bicep' -File
# What: condition check. Why: branch based on pass/fail state.
if (-not $bicepFiles) {
  # What: explicit failure. Why: stop pipeline when requirement is missing.
  throw 'No .bicep files found to validate.'
# What: close code block. Why: end current scope.
}

# What: loop start. Why: run check for each item.
foreach ($file in $bicepFiles) {
  # What: log output. Why: show progress/results in CI logs.
  Write-Host "[validate-iac] Building: $($file.FullName)"
  # What: Azure CLI command. Why: compile/validate templates.
  az bicep build --file $file.FullName | Out-Null
# What: close code block. Why: end current scope.
}

# What: log output. Why: show progress/results in CI logs.
Write-Host "[validate-iac] Success: all Bicep files compiled."




