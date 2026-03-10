# Git feature uninstallation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"
. "$DotfilesRoot\core\lib\runner.ps1"

$FeatureName = "git"

Log-Task "Uninstalling feature: $FeatureName"

$gitignoreTarget = Join-Path (Get-HomePath) ".gitignore_global"

# Tracked files are removed by executor. Keep secondary cleanup here.
if (Test-Command -Command "git") {
    try {
        $currentIgnore = (& git config --global --get core.excludesfile 2>$null | Select-Object -First 1)
        if ($currentIgnore -eq $gitignoreTarget) {
            & git config --global --unset core.excludesfile 2>$null | Out-Null
            Log-Info "Removed global gitignore configuration"
        }
    } catch {
        Log-Warn "Failed to clean global gitignore configuration: $_"
    }
}

Log-Success "Feature $FeatureName uninstalled successfully"
