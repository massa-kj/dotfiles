# node installation script for Windows

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

$FeatureName = "node"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Install Node.js via mise
if (Test-Runtime -Name "node" -Version "22.17.1") {
    Log-Info "node@22.17.1 is already installed"
} else {
    Log-Info "Installing node@22.17.1 via mise..."
    if (-not (Install-Runtime -Name "node" -Version "22.17.1")) {
        Log-Error "Failed to install node@22.17.1"
        exit 1
    }
    Log-Success "node@22.17.1 installed"
}
State-AddPackage -Feature $FeatureName -Package "node@22.17.1"

# Install npm packages
$npmPackages = @(
    "typescript",
    "typescript-language-server",
    "eslint"
)

foreach ($pkg in $npmPackages) {
    # Check if package is installed globally
    $installed = $false
    try {
        $result = & npm list -g $pkg 2>$null
        $installed = $LASTEXITCODE -eq 0
    } catch {
        $installed = $false
    }
    
    if ($installed) {
        Log-Info "npm package already installed: $pkg"
    } else {
        Log-Info "Installing npm package: $pkg"
        & npm install -g $pkg
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Failed to install npm package: $pkg"
            exit 1
        }
        Log-Success "npm package installed: $pkg"
    }
    State-AddPackage -Feature $FeatureName -Package "npm:$pkg"
}

Log-Success "Feature $FeatureName installed successfully"
