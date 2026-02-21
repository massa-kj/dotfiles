# lua uninstallation script for Windows

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

Log-Task "Uninstalling feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Get installed packages for this feature
$packages = @(State-GetPackages -Feature $FeatureName)
if ($packages.Count -eq 0) {
    Log-Info "No packages found for feature: $FeatureName"
    exit 0
}

Log-Info "Found $($packages.Count) packages to uninstall"

# Uninstall each package
foreach ($pkg in $packages) {
    if ($pkg -match "^([^@]+)@(.+)$") {
        # Runtime installed via mise
        $runtime = $Matches[1]
        $version = $Matches[2]
        
        Log-Info "Uninstalling runtime: $runtime@$version"
        if (-not (Uninstall-Runtime -Name $runtime -Version $version)) {
            Log-Warn "Failed to uninstall runtime: $runtime@$version"
        }
    } else {
        # Package installed via package manager
        Log-Info "Uninstalling package: $pkg"
        if (-not (Uninstall-Package -Name $pkg)) {
            Log-Warn "Failed to uninstall package: $pkg"
        }
    }
}

# Remove feature from state
State-RemoveFeature -Feature $FeatureName

Log-Success "Feature $FeatureName uninstalled successfully"
