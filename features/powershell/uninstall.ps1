# PowerShell configuration uninstallation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"

$FeatureName = "powershell"

Log-Task "Uninstalling feature: $FeatureName"

# Resources are removed by executor using recorded state.

Log-Success "Feature $FeatureName uninstalled successfully"
Write-Host ""
Write-Host "PowerShell profile has been removed." -ForegroundColor Green
Write-Host "Restart your PowerShell session to apply changes." -ForegroundColor Yellow
Write-Host ""
