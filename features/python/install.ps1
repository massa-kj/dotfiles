# python installation script for Windows

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

$FeatureName = "python"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Read version from profile (default: latest)
$Version = if ($env:DOTFILES_FEATURE_CONFIG_VERSION) { $env:DOTFILES_FEATURE_CONFIG_VERSION } else { "latest" }

# Install Python via mise
if (Test-Runtime -Name "python" -Version $Version) {
    Log-Info "python@$Version is already installed"
} else {
    Log-Info "Installing python@$Version via mise..."
    if (-not (Install-Runtime -Name "python" -Version $Version)) {
        Log-Error "Failed to install python@$Version"
        exit 1
    }
    Log-Success "python@$Version installed"
}
State-AddPackage -Feature $FeatureName -Package "python@$Version"
State-SetRuntime -Feature $FeatureName -Key "version" -Value $Version

# Install uv via mise
if (Test-Runtime -Name "uv" -Version "latest") {
    Log-Info "uv@latest is already installed"
} else {
    Log-Info "Installing uv@latest via mise..."
    if (-not (Install-Runtime -Name "uv" -Version "latest")) {
        Log-Error "Failed to install uv@latest"
        exit 1
    }
    Log-Success "uv@latest installed"
}
State-AddPackage -Feature $FeatureName -Package "uv@latest"

# Install python-lsp-server via uv
$installed = $false
try {
    $result = & uv pip list 2>$null | Select-String "python-lsp-server"
    $installed = $null -ne $result
} catch {
    $installed = $false
}

if ($installed) {
    Log-Info "python-lsp-server already installed"
} else {
    Log-Info "Installing python-lsp-server via uv..."
    & uv pip install --system python-lsp-server
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to install python-lsp-server"
        exit 1
    }
    Log-Success "python-lsp-server installed"
}
State-AddPackage -Feature $FeatureName -Package "uv:python-lsp-server"

Log-Success "Feature $FeatureName installed successfully"
