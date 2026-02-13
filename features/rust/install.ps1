# rust installation script for Windows

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

$FeatureName = "rust"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Install Rust via mise
if (Test-Runtime -Name "rust" -Version "1.87.0") {
    Log-Info "rust@1.87.0 is already installed"
} else {
    Log-Info "Installing rust@1.87.0 via mise..."
    if (-not (Install-Runtime -Name "rust" -Version "1.87.0")) {
        Log-Error "Failed to install rust@1.87.0"
        exit 1
    }
    Log-Success "rust@1.87.0 installed"
}
State-AddPackage -Feature $FeatureName -Package "rust@1.87.0"

# Install rust-analyzer via mise
if (Test-Runtime -Name "rust-analyzer" -Version "2025-05-26") {
    Log-Info "rust-analyzer@2025-05-26 is already installed"
} else {
    Log-Info "Installing rust-analyzer@2025-05-26 via mise..."
    if (-not (Install-Runtime -Name "rust-analyzer" -Version "2025-05-26")) {
        Log-Error "Failed to install rust-analyzer@2025-05-26"
        exit 1
    }
    Log-Success "rust-analyzer@2025-05-26 installed"
}
State-AddPackage -Feature $FeatureName -Package "rust-analyzer@2025-05-26"

Log-Success "Feature $FeatureName installed successfully"
