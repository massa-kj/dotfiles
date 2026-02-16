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

# Read-Profile <ProfileFile>
# Read profile YAML file and extract feature list.
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
        # Try using yq if available
        if (Get-Command yq -ErrorAction SilentlyContinue) {
            $features = & yq eval '.features[]' $ProfileFile 2>$null
            if ($LASTEXITCODE -eq 0 -and $features) {
                $featureList = @($features -split "`n" | Where-Object { $_ })
            } else {
                $featureList = @()
            }
        } else {
            # Fallback: simple YAML parsing
            $content = Get-Content $ProfileFile -Raw
            if ($content -match 'features:\s*\n((?:\s+-\s+.+\n?)*)') {
                $featuresText = $matches[1]
                $featureList = @($featuresText -split "`n" | ForEach-Object {
                    if ($_ -match '^\s+-\s+(.+)$') {
                        $matches[1].Trim()
                    }
                } | Where-Object { $_ })
            } else {
                $featureList = @()
            }
        }
        
        if ($featureList.Count -eq 0) {
            Log-Error "No features found in profile"
            return $null
        }
        
        Log-Info "Desired features: $($featureList -join ' ')"
        return $featureList
    } catch {
        Log-Error "Failed to read profile: $_"
        return $null
    }
}

# Get-FeatureDiff <SortedFeatures>
# Calculate difference between desired and installed features.
function Get-FeatureDiff {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$SortedFeatures
    )
    
    $installedFeatures = State-ListFeatures
    
    $toInstall = @()
    $toUninstall = @()
    
    # Find features to install
    foreach ($feature in $SortedFeatures) {
        if (-not (State-HasFeature -Feature $feature)) {
            $toInstall += $feature
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
    
    Log-Info "Features to install: $toInstallStr"
    Log-Info "Features to uninstall: $toUninstallStr"
    
    return @{
        ToInstall = $toInstall
        ToUninstall = $toUninstall
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
        
        Log-Info "Installing: $feature"
        try {
            & $installScript
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                throw "Script exited with code $LASTEXITCODE"
            }
        } catch {
            Log-Error "Failed to install: $feature - $_"
            return $false
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
