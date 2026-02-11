# PowerShell configuration installation script for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load core libraries
$ScriptDir = $PSScriptRoot
$DotfilesRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

. "$DotfilesRoot\core\lib\env.ps1"
. "$DotfilesRoot\core\lib\logger.ps1"
. "$DotfilesRoot\core\lib\state.ps1"
. "$DotfilesRoot\core\lib\fs.ps1"

$FeatureName = "powershell"

Log-Task "Installing feature: $FeatureName"

# Ensure state is initialized
if (-not (State-Init)) {
    exit 1
}

# Get PowerShell profile paths
$profileDir = Split-Path -Parent $PROFILE
$targetProfilePath = $PROFILE  # Microsoft.PowerShell_profile.ps1

Log-Info "PowerShell profile directory: $profileDir"
Log-Info "PowerShell profile path: $targetProfilePath"

# Source profile files
$featureFilesDir = Join-Path $ScriptDir "files"
$sourceDir = Join-Path $featureFilesDir "WindowsPowerShell"
$sourceProfilePath = Join-Path $sourceDir "Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $sourceProfilePath)) {
    Log-Error "Source profile not found: $sourceProfilePath"
    exit 1
}

# Check if profile directory exists
if (-not (Test-Path $profileDir)) {
    Log-Info "Creating PowerShell profile directory..."
    Ensure-Directory -Path $profileDir
}

# Check if profile already exists and is identical (idempotency)
if (Test-Path $targetProfilePath) {
    $targetContent = Get-Content $targetProfilePath -Raw -ErrorAction SilentlyContinue
    $sourceContent = Get-Content $sourceProfilePath -Raw
    
    if ($targetContent -eq $sourceContent) {
        Log-Info "PowerShell profile is already up to date"
        State-AddFile -Feature $FeatureName -File $targetProfilePath
        Log-Success "Feature $FeatureName installed successfully (already configured)"
        exit 0
    } else {
        Log-Warn "PowerShell profile exists with different content, will backup and replace"
    }
}

# Backup existing profile if exists
if (Test-Path $targetProfilePath) {
    Backup-File -Target $targetProfilePath
}

# Copy profile file
Log-Info "Deploying PowerShell profile..."
try {
    Copy-Item -Path $sourceProfilePath -Destination $targetProfilePath -Force
    State-AddFile -Feature $FeatureName -File $targetProfilePath
    Log-Success "PowerShell profile deployed: $targetProfilePath"
} catch {
    Log-Error "Failed to copy profile: $_"
    exit 1
}

# Optional: Link entire directory if user prefers
# Uncomment this section if you want to link the entire WindowsPowerShell directory
# instead of copying individual files
<#
$targetWindowsPowerShellDir = Join-Path (Split-Path -Parent $profileDir) "WindowsPowerShell"

if (Test-Path $targetWindowsPowerShellDir) {
    $item = Get-Item $targetWindowsPowerShellDir
    if ($item.LinkType) {
        # Already a symlink, check if it points to our directory
        $linkTarget = $item.Target
        if ($linkTarget -eq $sourceDir) {
            Log-Info "WindowsPowerShell directory already linked correctly"
        } else {
            Log-Warn "WindowsPowerShell directory is linked to a different location"
            Log-Info "Current target: $linkTarget"
            Log-Info "Expected target: $sourceDir"
        }
    } else {
        Log-Warn "WindowsPowerShell directory exists but is not a symlink"
        Log-Info "Using copied profile instead"
    }
} else {
    # Optionally create symlink for entire directory
    # Requires Administrator privileges or Developer Mode
    if (Test-Administrator) {
        Log-Info "Creating symlink for WindowsPowerShell directory..."
        if (New-DirectoryLink -Feature $FeatureName -Source $sourceDir -Destination $targetWindowsPowerShellDir) {
            Log-Success "WindowsPowerShell directory linked"
        }
    } else {
        Log-Info "Skipping directory symlink (requires Administrator privileges)"
    }
}
#>

Log-Success "Feature $FeatureName installed successfully"
Write-Host ""
Write-Host "PowerShell profile has been configured." -ForegroundColor Green
Write-Host "Restart your PowerShell session to apply changes." -ForegroundColor Yellow
Write-Host ""
