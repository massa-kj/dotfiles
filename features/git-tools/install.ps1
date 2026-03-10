# Git tools installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"

$FeatureName = "git-tools"

Log-Task "Installing feature: $FeatureName"

# Packages are installed by executor (declared in meta.yaml).

# Deploy lazygit configuration
$featureFilesDir = Join-Path $ScriptDir "files"
$lazygitSourceDir = Join-Path $featureFilesDir "lazygit"

if (Test-Path $lazygitSourceDir) {
    $lazygitTargetDir = Join-Path $env:LOCALAPPDATA "lazygit"
    Log-Info "Deploying lazygit configuration..."
    if (New-DirectoryLink -Feature $FeatureName -Source $lazygitSourceDir -Destination $lazygitTargetDir) {
        Log-Success "lazygit configuration deployed"
    } else {
        Log-Warn "Failed to deploy lazygit configuration"
    }
} else {
    Log-Info "No lazygit configuration to deploy"
}

Log-Success "Feature $FeatureName installed successfully"
