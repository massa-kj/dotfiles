# Dependency resolution and topological sorting

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1 and logger.ps1 to be loaded by the caller.

# Global variables for dependency graph
$script:FeatureDeps = @{}
$script:Visited = @{}
$script:InStack = @{}
$script:Sorted = @()

function Read-FeatureMetadata {
    <#
    .SYNOPSIS
    Read metadata for all features in profile
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Features
    )
    
    $script:FeatureDeps = @{}
    
    Log-Info "Reading feature metadata..."
    
    foreach ($feature in $Features) {
        $metaFile = Join-Path (Join-Path $global:DOTFILES_FEATURES_DIR $feature) "meta.yaml"
        $platformMetaFile = Join-Path (Join-Path $global:DOTFILES_FEATURES_DIR $feature) "meta.$($global:DOTFILES_PLATFORM).yaml"
        
        if (-not (Test-Path $metaFile)) {
            Log-Error "Meta file not found: $metaFile"
            return $false
        }
        
        # Read common dependencies
        $deps = @()
        try {
            if (Get-Command yq -ErrorAction SilentlyContinue) {
                $commonDeps = & yq eval '.depends[]' $metaFile 2>$null
                if ($LASTEXITCODE -eq 0 -and $commonDeps) {
                    $deps += @($commonDeps -split "`n" | Where-Object { $_ })
                }
            } else {
                # Fallback: simple YAML parsing for depends field
                $content = Get-Content $metaFile -Raw
                if ($content -match 'depends:\s*\n((?:\s+-\s+.+\n?)*)') {
                    $depsText = $matches[1]
                    $depsList = $depsText -split "`n" | ForEach-Object {
                        if ($_ -match '^\s+-\s+(.+)$') {
                            $matches[1].Trim()
                        }
                    } | Where-Object { $_ }
                    $deps += @($depsList)
                }
            }
            
            # Read platform-specific dependencies if exists
            if (Test-Path $platformMetaFile) {
                if (Get-Command yq -ErrorAction SilentlyContinue) {
                    $platformDeps = & yq eval '.depends[]' $platformMetaFile 2>$null
                    if ($LASTEXITCODE -eq 0 -and $platformDeps) {
                        $deps += @($platformDeps -split "`n" | Where-Object { $_ })
                    }
                } else {
                    # Fallback: simple YAML parsing
                    $content = Get-Content $platformMetaFile -Raw
                    if ($content -match 'depends:\s*\n((?:\s+-\s+.+\n?)*)') {
                        $depsText = $matches[1]
                        $depsList = $depsText -split "`n" | ForEach-Object {
                            if ($_ -match '^\s+-\s+(.+)$') {
                                $matches[1].Trim()
                            }
                        } | Where-Object { $_ }
                        $deps += @($depsList)
                    }
                }
            }
            
            # Store unique dependencies
            $uniqueDeps = $deps | Select-Object -Unique
            $script:FeatureDeps[$feature] = @($uniqueDeps)
            
            if ($script:FeatureDeps[$feature].Count -gt 0) {
                Log-Info "  $feature depends on: $($script:FeatureDeps[$feature] -join ', ')"
            } else {
                Log-Info "  $feature has no dependencies"
            }
        } catch {
            Log-Error "Failed to read metadata for ${feature}: $_"
            return $false
        }
    }
    
    return $true
}

function Invoke-TopoSortDFS {
    <#
    .SYNOPSIS
    Depth-first search for topological sort
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature,
        [Parameter(Mandatory=$true)]
        [string[]]$DesiredFeatures
    )
    
    # Check if already visited
    if ($script:Visited[$Feature]) {
        return $true
    }
    
    # Check for cycle
    if ($script:InStack[$Feature]) {
        Log-Error "Circular dependency detected involving: $Feature"
        return $false
    }
    
    $script:InStack[$Feature] = $true
    
    # Visit dependencies first
    $deps = $script:FeatureDeps[$Feature]
    if ($deps) {
        foreach ($dep in $deps) {
            # Check if dependency is in desired features
            if ($dep -notin $DesiredFeatures) {
                Log-Error "Dependency '$dep' (required by '$Feature') is not in profile"
                return $false
            }
            
            if (-not (Invoke-TopoSortDFS -Feature $dep -DesiredFeatures $DesiredFeatures)) {
                return $false
            }
        }
    }
    
    $script:InStack[$Feature] = $false
    $script:Visited[$Feature] = $true
    $script:Sorted += $Feature
    
    return $true
}

function Resolve-Dependencies {
    <#
    .SYNOPSIS
    Resolve dependencies and return sorted feature list
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$DesiredFeatures
    )
    
    $script:Visited = @{}
    $script:InStack = @{}
    $script:Sorted = @()
    
    Log-Info "Resolving dependencies..."
    
    # Sort all features
    foreach ($feature in $DesiredFeatures) {
        if (-not (Invoke-TopoSortDFS -Feature $feature -DesiredFeatures $DesiredFeatures)) {
            return $null
        }
    }
    
    Log-Success "Install order: $($script:Sorted -join ' ')"
    return $script:Sorted
}
