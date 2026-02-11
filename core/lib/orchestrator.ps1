# Orchestration of install/uninstall operations

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1, logger.ps1, and state.ps1 to be loaded by the caller.

function Read-Profile {
    <#
    .SYNOPSIS
    Read profile file and extract features
    #>
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

function Get-FeatureDiff {
    <#
    .SYNOPSIS
    Calculate diff between desired and installed features
    #>
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
    foreach ($feature in $installedFeatures) {
        if ($feature -notin $SortedFeatures) {
            $toUninstall += $feature
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

function Invoke-Uninstall {
    <#
    .SYNOPSIS
    Execute uninstall for features
    #>
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
        $uninstallScript = Join-Path $global:DOTFILES_FEATURES_DIR $feature "uninstall.ps1"
        
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

function Invoke-Install {
    <#
    .SYNOPSIS
    Execute install for features
    #>
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
        $installScript = Join-Path $global:DOTFILES_FEATURES_DIR $feature "install.ps1"
        
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

function Show-Summary {
    <#
    .SYNOPSIS
    Print summary of installed features
    #>
    
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

# Export functions
Export-ModuleMember -Function Read-Profile, Get-FeatureDiff, Invoke-Uninstall, Invoke-Install, Show-Summary
