# cmd/apply.ps1
# Apply command implementation

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptRoot = $PSScriptRoot
$global:DOTFILES_ROOT = (Get-Item "$ScriptRoot\..").FullName

. "$global:DOTFILES_ROOT\core\lib\env.ps1"
. "$global:DOTFILES_ROOT\core\lib\logger.ps1"
. "$global:DOTFILES_ROOT\core\lib\state.ps1"
. "$global:DOTFILES_ROOT\core\lib\resolver.ps1"
. "$global:DOTFILES_ROOT\core\lib\orchestrator.ps1"
. "$global:DOTFILES_ROOT\core\lib\runner.ps1"

# Platform check
if ($global:DOTFILES_PLATFORM -ne "windows") {
    Log-Error "This script is for Windows only. On Linux/WSL, run dotfiles instead."
    exit 1
}

# Usage
function Show-Usage {
    Write-Host @"
Usage: dotfiles.ps1 apply <profile.yaml>

Apply a dotfiles profile to the system.

Arguments:
  profile.yaml    Path to the profile file

Examples:
  dotfiles.ps1 apply profiles\minimal.yaml
  dotfiles.ps1 apply profiles\windows.yaml
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
