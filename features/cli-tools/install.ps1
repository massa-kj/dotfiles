# CLI tools installation script for Windows

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

$FeatureName = "cli-tools"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# List of tools to install
$tools = @(
    "7zip",
    "fd",
    "fzf",
    "gcc",
    "ghq",
    "ripgrep"
)

# Install each tool
foreach ($tool in $tools) {
    if (Test-Command $tool) {
        Log-Info "$tool is already installed"
    } else {
        Log-Info "Installing $tool..."
        if (-not (Install-Package -Name $tool)) {
            Log-Warn "Failed to install $tool, continuing..."
        } else {
            Log-Success "$tool installed"
        }
    }
    State-AddPackage -Feature $FeatureName -Package $tool
}

Log-Success "Feature $FeatureName installed successfully"
