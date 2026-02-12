# Visual C++ Redistributable installation script for Windows

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

$FeatureName = "vcredist"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Check if vcredist2022 is already installed
if (Test-Package -Name "vcredist2022") {
    Log-Info "vcredist2022 is already installed"
} else {
    Log-Info "Installing vcredist2022 package..."
    if (-not (Install-Package -Name "vcredist2022" -Bucket "extras")) {
        Log-Error "Failed to install vcredist2022"
        exit 1
    }
    Log-Success "vcredist2022 package installed"
}
State-AddPackage -Feature $FeatureName -Package "vcredist2022"

Log-Success "Feature $FeatureName installed successfully"
