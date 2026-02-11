# Git feature uninstallation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"

$FeatureName = "git"

Log-Task "Uninstalling feature: $FeatureName"

# Check if feature is installed
if (-not (State-HasFeature -Feature $FeatureName)) {
    Log-Warn "Feature $FeatureName is not installed"
    exit 0
}

# Remove configuration files tracked in state
Remove-TrackedFiles -Feature $FeatureName

# Note: We do NOT uninstall git package as it may be used by other tools
# Only remove dotfiles-managed configuration
Log-Info "Note: git package is not removed (may be used by other tools)"

# Remove feature from state
State-RemoveFeature -Feature $FeatureName

Log-Success "Feature $FeatureName uninstalled successfully"
