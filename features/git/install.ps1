# Git feature installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\package.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"
. "$DotfilesRoot\core\lib\runner.ps1"

$FeatureName = "git"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Check if git is already installed
if (Test-Command -Command "git") {
    Log-Info "git is already installed"
} else {
    Log-Info "Installing git package..."
    
    # Try to install via package manager
    if (Install-Package -Name "git") {
        State-AddPackage -Feature $FeatureName -Package "git"
        Log-Success "git package installed"
    } else {
        Log-Error "Failed to install git"
        exit 1
    }
}

# Deploy configuration files
$featureFilesDir = Join-Path $ScriptDir "files"
$targetHome = Get-HomePath

Log-Info "Deploying configuration files..."

# Git configuration
$gitconfigSource = Join-Path $featureFilesDir "gitconfig"
$gitconfigTarget = Join-Path $targetHome ".gitconfig"

if (Test-Path $gitconfigSource) {
    # Check for platform-specific config
    $gitconfigWindows = Join-Path $featureFilesDir ".gitconfig.windows"
    
    if (Test-Path $gitconfigWindows) {
        Log-Info "Merging gitconfig with Windows settings..."
        
        # Merge configurations
        $baseConfig = Get-Content $gitconfigSource -Raw
        $windowsConfig = Get-Content $gitconfigWindows -Raw
        $mergedConfig = $baseConfig + "`n" + $windowsConfig
        
        # Create temporary file
        $tempConfig = Join-Path $env:TEMP ".gitconfig.tmp"
        $mergedConfig | Set-Content $tempConfig -Encoding UTF8
        
        # Backup and copy
        Backup-File -Target $gitconfigTarget
        Copy-Item $tempConfig $gitconfigTarget -Force
        Remove-Item $tempConfig -Force
        
        State-AddFile -Feature $FeatureName -File $gitconfigTarget
        Log-Success "Deployed .gitconfig (with Windows settings)"
    } else {
        # Just copy base config
        Backup-File -Target $gitconfigTarget
        Copy-Item $gitconfigSource $gitconfigTarget -Force
        State-AddFile -Feature $FeatureName -File $gitconfigTarget
        Log-Success "Deployed .gitconfig"
    }
}

# Git ignore (global)
$gitignoreSource = Join-Path $featureFilesDir "ignore"
$gitignoreTarget = Join-Path $targetHome ".gitignore_global"

if (Test-Path $gitignoreSource) {
    Backup-File -Target $gitignoreTarget
    Copy-Item $gitignoreSource $gitignoreTarget -Force
    State-AddFile -Feature $FeatureName -File $gitignoreTarget
    Log-Success "Deployed .gitignore_global"
    
    # Configure git to use global gitignore
    try {
        & git config --global core.excludesfile $gitignoreTarget
        Log-Info "Configured global gitignore"
    } catch {
        Log-Warn "Failed to configure global gitignore: $_"
    }
}

Log-Success "Feature $FeatureName installed successfully"
