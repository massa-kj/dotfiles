# -----------------------------------------------------------------------------
# Module: orchestrator
#
# Responsibility:
#   Orchestrate feature installation and uninstallation workflow.
#
# Public API (Internal):
#   Read-Profile <ProfileFile>
#   Get-FeatureDiff <SortedFeatures>
#   Invoke-Uninstall <Features>
#   Invoke-Install <Features>
#   Show-Summary
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1, logger.ps1, and state.ps1 to be loaded by the caller.

# Global variable to cache profile data
$script:ProfileData = ""

# Read-Profile <ProfileFile>
# Read profile YAML file and extract feature names from map.
function Read-Profile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfileFile
    )
    
    if (-not (Test-Path $ProfileFile)) {
        Log-Error "Profile file not found: $ProfileFile"
        return $null
    }
    
    Log-Info "Reading profile..."
    
    try {
        # Cache full profile data for later config extraction
        $script:ProfileData = Get-Content $ProfileFile -Raw
        
        # Extract feature names (keys from features map)
        if (Get-Command yq -ErrorAction SilentlyContinue) {
            $features = & yq eval '.features | keys | .[]' $ProfileFile 2>$null
            if ($LASTEXITCODE -eq 0 -and $features) {
                $featureList = @($features -split "`n" | Where-Object { $_ })
            } else {
                $featureList = @()
            }
        } else {
            Log-Error "yq command not found. Please install yq."
            return $null
        }
        
        if ($featureList.Count -eq 0) {
            Log-Warn "Empty profile (no features specified)"
            Log-Info "All installed features will be uninstalled"
            return @()
        }
        
        Log-Info "Desired features: $($featureList -join ' ')"
        return $featureList
    } catch {
        Log-Error "Failed to read profile: $_"
        return $null
    }
}

# Get-FeatureConfig <Feature>
# Extract configuration for a specific feature from cached profile data.
function Get-FeatureConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )
    
    if (-not $script:ProfileData) {
        return $null
    }
    
    try {
        # Extract config for the feature (returns {} if empty or null)
        $config = $script:ProfileData | & yq eval ".features.${Feature}" -o=json - 2>$null
        if ($LASTEXITCODE -eq 0 -and $config) {
            return ($config | ConvertFrom-Json)
        }
    } catch {
        # Ignore errors, return null
    }
    
    return $null
}

# Test-VersionMismatch <Feature>
# Check if desired version differs from installed version.
# Returns: $true if mismatch, $false if match/no-version.
function Test-VersionMismatch {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )
    
    # Get desired version from profile
    $featureConfig = Get-FeatureConfig -Feature $Feature
    $desiredVersion = $null
    if ($featureConfig -and $featureConfig.version) {
        $desiredVersion = $featureConfig.version
    }
    
    # If no version specified in profile, no mismatch
    if (-not $desiredVersion) {
        return $false
    }
    
    # Get installed version from state
    $installedVersion = State-GetRuntime -Feature $Feature -Key "version"
    
    # If no installed version recorded, it's a mismatch
    if (-not $installedVersion) {
        return $true
    }
    
    # Compare versions
    return ($desiredVersion -ne $installedVersion)
}

# Get-FeatureDiff <SortedFeatures>
# Calculate difference between desired and installed features.
# Includes version mismatch detection for reinstall.
function Get-FeatureDiff {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$SortedFeatures
    )
    
    $installedFeatures = State-ListFeatures
    
    $toInstall = @()
    $toUninstall = @()
    $toReinstall = @()
    
    # Find features to install or reinstall
    foreach ($feature in $SortedFeatures) {
        if (-not (State-HasFeature -Feature $feature)) {
            $toInstall += $feature
        } elseif (Test-VersionMismatch -Feature $feature) {
            # Version mismatch detected
            Log-Info "Version mismatch detected for: $feature"
            $toReinstall += $feature
        }
    }
    
    # Find features to uninstall
    foreach ($installed in $installedFeatures) {
        if ($installed -notin $SortedFeatures) {
            $toUninstall += $installed
        }
    }
    
    $toInstallStr = if ($toInstall.Count -gt 0) { $toInstall -join ' ' } else { 'none' }
    $toUninstallStr = if ($toUninstall.Count -gt 0) { $toUninstall -join ' ' } else { 'none' }
    $toReinstallStr = if ($toReinstall.Count -gt 0) { $toReinstall -join ' ' } else { 'none' }
    
    Log-Info "Features to install: $toInstallStr"
    Log-Info "Features to uninstall: $toUninstallStr"
    Log-Info "Features to reinstall: $toReinstallStr"
    
    return @{
        ToInstall = $toInstall
        ToUninstall = $toUninstall
        ToReinstall = $toReinstall
    }
}

# Invoke-Uninstall <Features>
# Execute uninstall scripts for features in reverse order.
function Invoke-Uninstall {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [string[]]$Features
    )
    
    if ($Features.Count -eq 0) {
        return $true
    }
    
    Log-Task "Uninstalling features..."
    
    # Uninstall in reverse order
    [array]::Reverse($Features)
    
    foreach ($feature in $Features) {
        $uninstallScript = Join-Path (Join-Path $global:DOTFILES_FEATURES_DIR $feature) "uninstall.ps1"
        
        if (-not (Test-Path $uninstallScript)) {
            Log-Error "Uninstall script not found: $uninstallScript"
            return $false
        }
        
        Log-Info "Uninstalling: $feature"
        try {
            & $uninstallScript
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                throw "Script exited with code $LASTEXITCODE"
            }
        } catch {
            Log-Error "Failed to uninstall: $feature - $_"
            return $false
        }
    }
    
    return $true
}

# Invoke-Install <Features>
# Execute install scripts for features in dependency order.
function Invoke-Install {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [string[]]$Features
    )
    
    if ($Features.Count -eq 0) {
        return $true
    }
    
    Log-Task "Installing features..."
    
    foreach ($feature in $Features) {
        $installScript = Join-Path (Join-Path $global:DOTFILES_FEATURES_DIR $feature) "install.ps1"
        
        if (-not (Test-Path $installScript)) {
            Log-Error "Install script not found: $installScript"
            return $false
        }
        
        # Extract feature config and pass via environment variable
        $featureConfig = Get-FeatureConfig -Feature $feature
        $featureVersion = $null
        if ($featureConfig -and $featureConfig.version) {
            $featureVersion = $featureConfig.version
        }
        
        Log-Info "Installing: $feature"
        
        # Export config for install script to use
        if ($featureVersion) {
            $env:DOTFILES_FEATURE_CONFIG_VERSION = $featureVersion
        }
        
        try {
            & $installScript
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                throw "Script exited with code $LASTEXITCODE"
            }
        } catch {
            Log-Error "Failed to install: $feature - $_"
            return $false
        } finally {
            # Clear env var after install
            if ($env:DOTFILES_FEATURE_CONFIG_VERSION) {
                Remove-Item Env:\DOTFILES_FEATURE_CONFIG_VERSION -ErrorAction SilentlyContinue
            }
        }
    }
    
    return $true
}

# Show-Summary
# Display summary of successfully installed features.
function Show-Summary {
    Write-Host ""
    Log-Success "Profile applied successfully!"
    Write-Host ""
    Write-Host "Installed features:"
    
    $features = State-ListFeatures
    foreach ($feature in $features) {
        Write-Host "  ✓ $feature"
    }
    
    Write-Host ""
}
