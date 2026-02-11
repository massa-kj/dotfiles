# Git tools installation script for Windows

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

$FeatureName = "git-tools"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# List of tools to install
$tools = @(
    "delta",
    "lazygit"
)

# Install each tool
foreach ($tool in $tools) {
    if (Test-Command $tool) {
        Log-Info "$tool is already installed"
    } else {
        Log-Info "Installing $tool..."
        if (-not (Install-Package -Name $tool)) {
            Log-Error "Failed to install $tool"
            exit 1
        }
        Log-Success "$tool installed"
    }
    State-AddPackage -Feature $FeatureName -Package $tool -Manager (Get-PackageManager)
}

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
