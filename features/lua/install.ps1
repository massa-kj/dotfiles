# lua installation script for Windows

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

$FeatureName = "lua"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Install luacheck via scoop (not available in mise)
if (Test-Package -Name "luacheck") {
    Log-Info "luacheck is already installed"
} else {
    Log-Info "Installing luacheck package..."
    if (-not (Install-Package -Name "luacheck")) {
        Log-Error "Failed to install luacheck"
        exit 1
    }
    Log-Success "luacheck package installed"
}
State-AddPackage -Feature $FeatureName -Package "luacheck"

# Install stylua via mise
if (Test-Runtime -Name "stylua" -Version "2.1.0") {
    Log-Info "stylua@2.1.0 is already installed"
} else {
    Log-Info "Installing stylua@2.1.0 via mise..."
    if (-not (Install-Runtime -Name "stylua" -Version "2.1.0")) {
        Log-Error "Failed to install stylua@2.1.0"
        exit 1
    }
    Log-Success "stylua@2.1.0 installed"
}
State-AddPackage -Feature $FeatureName -Package "stylua@2.1.0"

# Install lua-language-server via mise
if (Test-Runtime -Name "lua-language-server" -Version "3.14.0") {
    Log-Info "lua-language-server@3.14.0 is already installed"
} else {
    Log-Info "Installing lua-language-server@3.14.0 via mise..."
    if (-not (Install-Runtime -Name "lua-language-server" -Version "3.14.0")) {
        Log-Error "Failed to install lua-language-server@3.14.0"
        exit 1
    }
    Log-Success "lua-language-server@3.14.0 installed"
}
State-AddPackage -Feature $FeatureName -Package "lua-language-server@3.14.0"

Log-Success "Feature $FeatureName installed successfully"
