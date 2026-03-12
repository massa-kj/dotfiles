# Neovim installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"

$FeatureName = "neovim"

Log-Task "Installing feature: $FeatureName"

# Read version from profile config (optional for neovim)
$Version = if ($env:DOTFILES_FEATURE_CONFIG_VERSION) { 
    $env:DOTFILES_FEATURE_CONFIG_VERSION 
} else { 
    "latest" 
}
if ($Version -ne "latest") {
    Log-Info "Target Neovim version: $Version"
}

# Package installation is handled by executor (declared in feature.yaml).

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
