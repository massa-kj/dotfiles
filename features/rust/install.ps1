# rust installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"

$FeatureName = "rust"

Log-Task "Installing feature: $FeatureName"

# Read version from profile (default: latest)
$Version = if ($env:DOTFILES_FEATURE_CONFIG_VERSION) { $env:DOTFILES_FEATURE_CONFIG_VERSION } else { "latest" }
Log-Info "Target Rust version: $Version"

# Runtimes are installed by executor (declared in meta.yaml).

Log-Success "Feature $FeatureName installed successfully"
