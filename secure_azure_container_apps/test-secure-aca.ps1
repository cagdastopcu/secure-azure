# This attribute turns the script into an advanced function-style script so we get better parameter behavior and common switches.
[CmdletBinding()]

# This block declares all input parameters users pass when they run the script.
param(
  # This is the Azure Resource Group that will be validated/deployed against.
  [Parameter(Mandatory = $true)]
  [string]$ResourceGroupName,

  # This is the Azure region for RG creation if the group does not already exist.
  [Parameter(Mandatory = $false)]
  [string]$Location = 'westeurope',

  # This short prefix becomes part of resource names inside the Bicep template.
  [Parameter(Mandatory = $false)]
  [string]$Prefix = 'acatest',

  # This points to the Bicep file we want to test.
  [Parameter(Mandatory = $false)]
  [string]$TemplateFile = (Join-Path $PSScriptRoot 'main.bicep'),

  # This switch controls whether we only test (validate/what-if) or also do a real deployment.
  [Parameter(Mandatory = $false)]
  [switch]$Deploy,

  # This switch toggles private registry mode in the template parameters.
  [Parameter(Mandatory = $false)]
  [switch]$UsePrivateRegistry,

  # This switch toggles public ingress in the template parameters.
  [Parameter(Mandatory = $false)]
  [switch]$EnableExternalIngress,

  # This optional Key Vault secret URL is passed into the template for secure secret reference.
  [Parameter(Mandatory = $false)]
  [string]$KeyVaultSecretUrl = '',

  # This optional subscription id lets you force the script to a specific Azure subscription context.
  [Parameter(Mandatory = $false)]
  [string]$SubscriptionId = ''
)

# Strict mode catches common scripting mistakes early (for example, typos in variable names).
Set-StrictMode -Version Latest

# Stop on any unhandled error so we fail fast and avoid partial/broken execution.
$ErrorActionPreference = 'Stop'

# This helper tries known Azure CLI locations and returns the first usable executable path.
function Find-AzCli {
  # Candidate locations include PATH name and common Windows install paths.
  $candidates = @(
    'az',
    'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd',
    'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.exe'
  )

  # Loop through each candidate and test if it responds to `--version`.
  foreach ($candidate in $candidates) {
    try {
      # Try to run Azure CLI version command and ignore stderr noise during probing.
      $null = & $candidate --version 2>$null

      # If process exit code is zero, this candidate is valid.
      if ($LASTEXITCODE -eq 0) {
        return $candidate
      }
    }
    catch {
      # If one candidate fails, continue to the next candidate path.
      continue
    }
  }

  # If all candidates fail, stop with a clear action message.
  throw 'Azure CLI (az) was not found. Install Azure CLI or add it to PATH.'
}

# This helper runs an az command and parses JSON output into a PowerShell object.
function Run-AzJson {
  param(
    # Fully qualified az path or command name returned by Find-AzCli.
    [Parameter(Mandatory = $true)]
    [string]$AzPath,

    # Array of command arguments to avoid fragile string-concatenated shell commands.
    [Parameter(Mandatory = $true)]
    [string[]]$Args
  )

  # Execute az with argument array so PowerShell handles quoting safely.
  $output = & $AzPath @Args

  # Fail if az reports a non-zero exit code.
  if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI command failed: az $($Args -join ' ')"
  }

  # Return $null for empty output instead of trying to parse empty JSON.
  if ([string]::IsNullOrWhiteSpace(($output -join ''))) {
    return $null
  }

  # Parse JSON text into a structured object for safe property access.
  return ($output | ConvertFrom-Json)
}

# This helper runs az commands where we only care about success/failure and not JSON result.
function Run-Az {
  param(
    # Fully qualified az path or command name returned by Find-AzCli.
    [Parameter(Mandatory = $true)]
    [string]$AzPath,

    # Array of command arguments to avoid quoting bugs.
    [Parameter(Mandatory = $true)]
    [string[]]$Args
  )

  # Execute the Azure CLI command.
  & $AzPath @Args

  # Fail fast on non-zero exit code to stop risky partial workflows.
  if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI command failed: az $($Args -join ' ')"
  }
}

# Resolve working az executable before doing any Azure operation.
$az = Find-AzCli

# Print selected executable so user can see which az path is used.
Write-Host "Using Azure CLI: $az" -ForegroundColor Cyan

# Stop immediately if the Bicep file path is wrong.
if (-not (Test-Path -LiteralPath $TemplateFile)) {
  throw "Template file not found: $TemplateFile"
}

# If subscription is explicitly provided, switch context to that subscription.
if (-not [string]::IsNullOrWhiteSpace($SubscriptionId)) {
  Run-Az -AzPath $az -Args @('account', 'set', '--subscription', $SubscriptionId)
}

# Read current account context so we log exactly where the script is running.
$account = Run-AzJson -AzPath $az -Args @('account', 'show', '--output', 'json')

# Show subscription name/id to prevent accidental deployment into wrong subscription.
Write-Host "Active subscription: $($account.name) ($($account.id))" -ForegroundColor Green

# Start RG existence check.
Write-Host 'Checking resource group...' -ForegroundColor Cyan

# Query whether resource group exists.
$rgExists = & $az group exists --name $ResourceGroupName

# If existence check command itself fails, stop.
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to check resource group existence.'
}

# Normalize output and create RG when it does not exist.
if (($rgExists | Out-String).Trim().ToLowerInvariant() -ne 'true') {
  # Inform user we are creating RG automatically.
  Write-Host "Creating resource group $ResourceGroupName in $Location" -ForegroundColor Yellow

  # Create resource group quietly (`--output none`) to reduce console noise.
  Run-Az -AzPath $az -Args @('group', 'create', '--name', $ResourceGroupName, '--location', $Location, '--output', 'none')
}

# Deployment name uses timestamp to avoid name collision between runs.
$deploymentName = "aca-test-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"

# Compile check catches syntax/type errors early before ARM validation.
Write-Host 'Step 1/5: Compile Bicep...' -ForegroundColor Cyan
Run-Az -AzPath $az -Args @('bicep', 'build', '--file', $TemplateFile)

# Build `validate` command arguments in an array for safe quoting and readability.
$paramArgs = @(
  'deployment', 'group', 'validate',
  '--resource-group', $ResourceGroupName,
  '--name', $deploymentName,
  '--template-file', $TemplateFile,
  '--parameters', "prefix=$Prefix",
  '--parameters', "usePrivateRegistry=$($UsePrivateRegistry.IsPresent.ToString().ToLowerInvariant())",
  '--parameters', "enableExternalIngress=$($EnableExternalIngress.IsPresent.ToString().ToLowerInvariant())",
  '--parameters', "keyVaultSecretUrl=$KeyVaultSecretUrl",
  '--output', 'json'
)

# ARM validation checks schema, API contracts, and deployment viability at control plane level.
Write-Host 'Step 2/5: Validate template with ARM...' -ForegroundColor Cyan
$validateResult = Run-AzJson -AzPath $az -Args $paramArgs

# Defensive check: make sure validate produced a response object.
if ($null -eq $validateResult) {
  throw 'Validation returned empty result.'
}

# Inform user validation succeeded.
Write-Host 'Validation passed.' -ForegroundColor Green

# Build `what-if` command arguments to preview change impact before deployment.
$whatIfArgs = @(
  'deployment', 'group', 'what-if',
  '--resource-group', $ResourceGroupName,
  '--name', "$deploymentName-whatif",
  '--template-file', $TemplateFile,
  '--parameters', "prefix=$Prefix",
  '--parameters', "usePrivateRegistry=$($UsePrivateRegistry.IsPresent.ToString().ToLowerInvariant())",
  '--parameters', "enableExternalIngress=$($EnableExternalIngress.IsPresent.ToString().ToLowerInvariant())",
  '--parameters', "keyVaultSecretUrl=$KeyVaultSecretUrl",
  '--result-format', 'ResourceIdOnly',
  '--no-pretty-print',
  '--output', 'json'
)

# What-if gives change preview (create/modify/delete) without applying resources.
Write-Host 'Step 3/5: Run what-if preview...' -ForegroundColor Cyan
$whatIfResult = Run-AzJson -AzPath $az -Args $whatIfArgs

# Print lightweight summary when change details are available.
if ($null -ne $whatIfResult -and $null -ne $whatIfResult.changes) {
  Write-Host "What-if detected $($whatIfResult.changes.Count) change item(s)." -ForegroundColor Yellow
}
else {
  # Some cases return no explicit `changes` array; still report completion.
  Write-Host 'What-if completed. No explicit changes array returned.' -ForegroundColor Yellow
}

# If user did not request deployment, stop here to keep test non-destructive.
if (-not $Deploy.IsPresent) {
  Write-Host 'Step 4/5: Skipped deployment because -Deploy was not provided.' -ForegroundColor Yellow
  Write-Host 'Done. This was a non-destructive test run (build + validate + what-if).' -ForegroundColor Green
  exit 0
}

# Build actual deployment arguments for create operation.
$deployArgs = @(
  'deployment', 'group', 'create',
  '--resource-group', $ResourceGroupName,
  '--name', "$deploymentName-deploy",
  '--template-file', $TemplateFile,
  '--parameters', "prefix=$Prefix",
  '--parameters', "usePrivateRegistry=$($UsePrivateRegistry.IsPresent.ToString().ToLowerInvariant())",
  '--parameters', "enableExternalIngress=$($EnableExternalIngress.IsPresent.ToString().ToLowerInvariant())",
  '--parameters', "keyVaultSecretUrl=$KeyVaultSecretUrl",
  '--output', 'json'
)

# Deploy the template now because -Deploy switch is present.
Write-Host 'Step 4/5: Deploy template...' -ForegroundColor Cyan
$deployResult = Run-AzJson -AzPath $az -Args $deployArgs

# Read container app resource id from deployment outputs.
$appResourceId = $deployResult.properties.outputs.containerAppResourceId.value

# Read environment resource id from deployment outputs.
$environmentResourceId = $deployResult.properties.outputs.managedEnvironmentId.value

# Read app FQDN from deployment outputs.
$appFqdn = $deployResult.properties.outputs.containerAppFqdn.value

# Defensive check for output integrity so later API calls do not use empty ids.
if ([string]::IsNullOrWhiteSpace($appResourceId)) {
  throw 'Deployment completed but containerAppResourceId output is empty.'
}

# Start post-deployment security smoke tests.
Write-Host 'Step 5/5: Security smoke checks...' -ForegroundColor Cyan

# Query the deployed app directly from ARM resource API for configuration verification.
$app = Run-AzJson -AzPath $az -Args @('resource', 'show', '--ids', $appResourceId, '--api-version', '2025-01-01', '--output', 'json')

# Read ingress insecure-HTTP flag we expect to be false for secure baseline.
$allowInsecure = $app.properties.configuration.ingress.allowInsecure

# Read revision mode we expect to be Single in this baseline.
$activeRevisionsMode = $app.properties.configuration.activeRevisionsMode

# Read identity type to confirm managed identity is enabled.
$identityType = $app.identity.type

# Fail if insecure HTTP is not blocked.
if ($allowInsecure -ne $false) {
  throw 'Security check failed: ingress.allowInsecure is not false.'
}

# Fail if revision mode is not Single.
if ($activeRevisionsMode -ne 'Single') {
  throw "Security check failed: activeRevisionsMode expected 'Single' but got '$activeRevisionsMode'."
}

# Fail if identity type is missing/empty.
if ([string]::IsNullOrWhiteSpace($identityType)) {
  throw 'Security check failed: managed identity is missing on container app.'
}

# Print success summary and key identifiers after all checks pass.
Write-Host "Security checks passed. App FQDN: $appFqdn" -ForegroundColor Green
Write-Host "Container App ID: $appResourceId" -ForegroundColor Green
Write-Host "Environment ID: $environmentResourceId" -ForegroundColor Green
Write-Host 'Test script finished successfully.' -ForegroundColor Green
