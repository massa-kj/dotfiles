# Neovim uninstallation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\package.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"

$FeatureName = "neovim"

Log-Task "Uninstalling feature: $FeatureName"

# Check if feature is installed
if (-not (State-HasFeature -Feature $FeatureName)) {
    Log-Warn "Feature $FeatureName is not installed"
    exit 0
}

# Remove tracked files and directories
Remove-TrackedFiles -Feature $FeatureName

# Uninstall packages
$packages = State-GetPackages -Feature $FeatureName
foreach ($pkg in $packages) {
    Log-Info "Uninstalling package: $($pkg.name)"
    Uninstall-Package -Name $pkg.name
}

# Remove feature from state
State-RemoveFeature -Feature $FeatureName

Log-Success "Feature $FeatureName uninstalled successfully"
