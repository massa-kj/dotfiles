# CLI tools installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"

$FeatureName = "cli-tools"

Log-Task "Installing feature: $FeatureName"

# Packages are installed by executor (declared in meta.windows.yaml).

Log-Success "Feature $FeatureName installed successfully"
