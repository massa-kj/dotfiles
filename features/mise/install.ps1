# mise installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\package.ps1"
. "$DotfilesRoot\core\lib\runner.ps1"

$FeatureName = "mise"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Check if mise is already installed
if (Test-Command "mise") {
    Log-Info "mise is already installed"
} else {
    Log-Info "Installing mise package..."
    if (-not (Install-Package -Name "mise")) {
        Log-Error "Failed to install mise"
        exit 1
    }
    Log-Success "mise package installed"
}
State-AddPackage -Feature $FeatureName -Package "mise"

# Deploy configuration files if they exist
$featureFilesDir = Join-Path $ScriptDir "files"
$targetMiseDir = Join-Path $env:USERPROFILE ".config\mise"

if (Test-Path $featureFilesDir) {
    Log-Info "Deploying mise configuration..."
    
    # Deploy config.toml if exists
    $configFile = Join-Path $featureFilesDir "config.toml"
    if (Test-Path $configFile) {
        $targetConfig = Join-Path $targetMiseDir "config.toml"
        if (New-FileLink -Feature $FeatureName -Source $configFile -Destination $targetConfig) {
            Log-Success "mise configuration deployed"
        }
    }
}

Log-Success "Feature $FeatureName installed successfully"
Write-Host ""
Write-Host "mise has been installed." -ForegroundColor Green
Write-Host "mise activation is configured in PowerShell profile." -ForegroundColor Cyan
Write-Host "Reload your shell to activate mise." -ForegroundColor Yellow
Write-Host ""
