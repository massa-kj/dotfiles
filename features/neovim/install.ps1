# Neovim installation script for Windows

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
. "$DotfilesRoot\core\lib\runner.ps1"

$FeatureName = "neovim"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Check if neovim is already installed
if (Test-Command "nvim") {
    Log-Info "neovim is already installed"
} else {
    Log-Info "Installing neovim package..."
    if (-not (Install-Package -Name "neovim")) {
        Log-Error "Failed to install neovim"
        exit 1
    }
    Log-Success "neovim package installed"
}
State-AddPackage -Feature $FeatureName -Package "neovim"

# Deploy configuration files
$featureFilesDir = Join-Path $ScriptDir "files\nvim"
$targetNvimDir = Join-Path $env:LOCALAPPDATA "nvim"

if (Test-Path $featureFilesDir) {
    Log-Info "Deploying Neovim configuration..."
    if (New-DirectoryLink -Feature $FeatureName -Source $featureFilesDir -Destination $targetNvimDir) {
        Log-Success "Neovim configuration deployed"
    } else {
        Log-Error "Failed to deploy Neovim configuration"
        exit 1
    }
} else {
    Log-Warn "Neovim configuration directory not found: $featureFilesDir"
}

Log-Success "Feature $FeatureName installed successfully"
Log-Info "Run 'nvim' to install plugins automatically"
