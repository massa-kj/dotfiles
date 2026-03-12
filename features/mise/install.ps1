# mise installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\runner.ps1"

$FeatureName = "mise"

Log-Task "Installing feature: $FeatureName"

# Package installation is handled by executor (declared in feature.yaml).
if (Test-Command "mise") {
    Log-Info "mise is available"
} else {
    Log-Warn "mise not found in PATH; a shell reload may be required after installation"
}

Log-Success "Feature $FeatureName installed successfully"
Write-Host ""
Write-Host "mise has been installed." -ForegroundColor Green
Write-Host "mise activation is configured in PowerShell profile." -ForegroundColor Cyan
Write-Host "Reload your shell to activate mise." -ForegroundColor Yellow
Write-Host ""
