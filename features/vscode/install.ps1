# VS Code portable feature installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"
. "$DotfilesRoot\core\lib\runner.ps1"
. "$DotfilesRoot\core\lib\repo.ps1"

$FeatureName = "vscode"
$RepoUrl     = "https://github.com/massa-kj/vscode-portable.git"
$RepoDir     = Join-Path $env:USERPROFILE ".local\src\vscode-portable"
$BinDir      = Join-Path $env:USERPROFILE ".local\bin"
$LaunchSrc   = Join-Path $RepoDir "launch.cmd"
$LaunchDst   = Join-Path $BinDir "vscode-launch"
$UpdateSrc   = Join-Path $RepoDir "update.ps1"
$UpdateDst   = Join-Path $BinDir "vscode-update"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Clone or update repository
Clone-Repository -Feature $FeatureName -RepoUrl $RepoUrl -DestPath $RepoDir

# Ensure ~/.local/bin exists
Ensure-Directory -Path $BinDir

# Link launch.cmd -> ~/.local/bin/launch-vscode.cmd
if (-not (Test-Path $LaunchSrc)) {
    Log-Error "launch.cmd not found in repository: $LaunchSrc"
    exit 1
}

if (-not (New-FileLink -Feature $FeatureName -Source $LaunchSrc -Destination $LaunchDst)) {
    Log-Error "Failed to link launch-vscode.cmd"
    exit 1
}

# Link update.ps1 -> ~/.local/bin/vscode-update.ps1
if (-not (Test-Path $UpdateSrc)) {
    Log-Error "update.ps1 not found in repository: $UpdateSrc"
    exit 1
}

if (-not (New-FileLink -Feature $FeatureName -Source $UpdateSrc -Destination $UpdateDst)) {
    Log-Error "Failed to link vscode-update.ps1"
    exit 1
}

Log-Success "Feature $FeatureName installed successfully"
Log-Info "Launcher available at: $LaunchDst"
Log-Info "Updater available at: $UpdateDst"
Log-Info "Add '$BinDir' to PATH if not already present"
