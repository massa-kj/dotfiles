# PowerShell configuration uninstallation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"

$FeatureName = "powershell"

Log-Task "Uninstalling feature: $FeatureName"

# Check if feature is installed
if (-not (State-HasFeature -Feature $FeatureName)) {
    Log-Warn "Feature $FeatureName is not installed"
    exit 0
}

# Remove tracked files
Remove-TrackedFiles -Feature $FeatureName

# Remove feature from state
State-RemoveFeature -Feature $FeatureName

Log-Success "Feature $FeatureName uninstalled successfully"
Write-Host ""
Write-Host "PowerShell profile has been removed." -ForegroundColor Green
Write-Host "Restart your PowerShell session to apply changes." -ForegroundColor Yellow
Write-Host ""
