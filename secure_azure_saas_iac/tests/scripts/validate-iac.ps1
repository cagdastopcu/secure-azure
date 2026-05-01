param(
  [string]$IaCRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

Require-Command -Name 'az'

Write-Host "[validate-iac] Installing/updating Bicep CLI via Azure CLI..."
az bicep install | Out-Null

$bicepFiles = Get-ChildItem -Path $IaCRoot -Recurse -Filter '*.bicep' -File
if (-not $bicepFiles) {
  throw 'No .bicep files found to validate.'
}

foreach ($file in $bicepFiles) {
  Write-Host "[validate-iac] Building: $($file.FullName)"
  az bicep build --file $file.FullName | Out-Null
}

Write-Host "[validate-iac] Success: all Bicep files compiled."
