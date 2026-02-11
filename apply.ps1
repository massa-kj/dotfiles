# apply.ps1
# Entry point for applying dotfiles profiles

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptRoot = $PSScriptRoot
$global:DOTFILES_ROOT = $ScriptRoot

. "$ScriptRoot\core\lib\env.ps1"
. "$ScriptRoot\core\lib\logger.ps1"
. "$ScriptRoot\core\lib\state.ps1"
. "$ScriptRoot\core\lib\resolver.ps1"
. "$ScriptRoot\core\lib\orchestrator.ps1"
. "$ScriptRoot\core\lib\runner.ps1"

# Platform check
if ($global:DOTFILES_PLATFORM -ne "windows") {
    Log-Error "This script is for Windows only. On Linux/WSL, run apply.sh instead."
    exit 1
}

# Usage
function Show-Usage {
    Write-Host @"
Usage: .\apply.ps1 <profile.yaml>

Apply a dotfiles profile to the system.

Arguments:
  profile.yaml    Path to the profile file

Examples:
  .\apply.ps1 profiles\minimal.yaml
  .\apply.ps1 profiles\windows.yaml
"@
    exit 1
}

# Parse arguments
if ($args.Count -lt 1) {
    Show-Usage
}

$ProfileFile = $args[0]

# Check if profile file exists
if (-not (Test-Path $ProfileFile)) {
    Log-Error "Profile file not found: $ProfileFile"
    exit 1
}

Log-Task "Applying profile: $ProfileFile"

# Initialize state
if (-not (State-Init)) {
    Log-Error "Failed to initialize state"
    exit 1
}

# Read profile
$desiredFeatures = Read-Profile -ProfileFile $ProfileFile
if (-not $desiredFeatures) {
    exit 1
}

# Read metadata and resolve dependencies
if (-not (Read-FeatureMetadata -Features $desiredFeatures)) {
    exit 1
}

$sortedFeatures = Resolve-Dependencies -DesiredFeatures $desiredFeatures
if (-not $sortedFeatures) {
    exit 1
}

# Calculate diff
$diff = Get-FeatureDiff -SortedFeatures $sortedFeatures

# Execute uninstall and install
if (-not (Invoke-Uninstall -Features $diff.ToUninstall)) {
    exit 1
}

if (-not (Invoke-Install -Features $diff.ToInstall)) {
    exit 1
}

# Print summary
Show-Summary
