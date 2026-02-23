# VS Code portable feature uninstallation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"

$FeatureName = "vscode"

Log-Task "Uninstalling feature: $FeatureName"

# Check if feature is installed
if (-not (State-HasFeature -Feature $FeatureName)) {
    Log-Warn "Feature $FeatureName is not installed"
    exit 0
}

# Remove all files and directories registered in state (launcher + cloned repo)
Remove-TrackedFiles -Feature $FeatureName

# Remove feature from state
State-RemoveFeature -Feature $FeatureName

Log-Success "Feature $FeatureName uninstalled successfully"
