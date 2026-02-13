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

# Install Python via mise
if (Test-Runtime -Name "python" -Version "3.12") {
    Log-Info "python@3.12 is already installed"
} else {
    Log-Info "Installing python@3.12 via mise..."
    if (-not (Install-Runtime -Name "python" -Version "3.12")) {
        Log-Error "Failed to install python@3.12"
        exit 1
    }
    Log-Success "python@3.12 installed"
}
State-AddPackage -Feature $FeatureName -Package "python@3.12"

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
