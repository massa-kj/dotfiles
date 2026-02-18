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

# Read version from profile (default: latest)
$Version = if ($env:DOTFILES_FEATURE_CONFIG_VERSION) { $env:DOTFILES_FEATURE_CONFIG_VERSION } else { "latest" }

# Install Rust via mise
if (Test-Runtime -Name "rust" -Version $Version) {
    Log-Info "rust@$Version is already installed"
} else {
    Log-Info "Installing rust@$Version via mise..."
    if (-not (Install-Runtime -Name "rust" -Version $Version)) {
        Log-Error "Failed to install rust@$Version"
        exit 1
    }
    Log-Success "rust@$Version installed"
}
State-AddPackage -Feature $FeatureName -Package "rust@$Version"
State-SetRuntime -Feature $FeatureName -Key "version" -Value $Version

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
