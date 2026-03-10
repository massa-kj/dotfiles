# -----------------------------------------------------------------------------
# Module: resolver
#
# Responsibility:
#   Resolve feature dependencies and perform topological sorting.
#   Supports capability-based dependencies via requires/provides fields.
#
# Public API (Stable):
#   Resolve-Dependencies <DesiredFeatures>
#   Read-FeatureMetadata <Features>
#   Invoke-TopoSortDFS <Feature> <DesiredFeatures>
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1 and logger.ps1 to be loaded by the caller.

# Lazily source source_registry if not already loaded
if (-not (Get-Command Canonical-Id-Normalize -ErrorAction SilentlyContinue)) {
    . "$env:DOTFILES_ROOT\core\lib\source_registry.ps1"
}

function _Resolver-GetFeatureDir {
    param([Parameter(Mandatory=$true)] [string]$Feature)

    $parts = Canonical-Id-Parse $Feature
    $featureRoot = Source-Registry-GetFeatureDir -SourceId $parts.SourceId
    return Join-Path $featureRoot $parts.Name
}

# Global variables for dependency graph
$script:FeatureDeps = @{}
$script:Visited = @{}
$script:InStack = @{}
$script:Sorted = @()

# Capability maps
$script:Provides = @{}   # capability -> [features that provide it]
$script:Requires = @{}   # feature    -> [capabilities required]

# Read-FeatureMetadata <Features>
# Read dependency metadata from meta.yaml files for all features.
# Populates FeatureDeps, Provides, and Requires module-globals.
function Read-FeatureMetadata {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Features
    )

    $script:FeatureDeps = @{}
    $script:Provides    = @{}
    $script:Requires    = @{}

    if (-not (Source-Registry-Load)) {
        return $false
    }

    Log-Info "Reading feature metadata..."

    foreach ($feature in $Features) {
        $parts = Canonical-Id-Parse $feature
        $featName = $parts.Name
        $sourceId = $parts.SourceId

        if (-not (Source-Registry-IsAllowed -SourceId $sourceId -FeatureName $featName)) {
            Log-Error "Read-FeatureMetadata: feature is not allowed by source registry: $feature"
            return $false
        }

        $featureDir = _Resolver-GetFeatureDir -Feature $feature
        $metaFile = Join-Path $featureDir "meta.yaml"

        # Resolve platform-specific meta file
        $platformMetaFile = $null
        $platformFile = Join-Path $featureDir "meta.$($global:DOTFILES_PLATFORM).yaml"
        # WSL also falls back to meta.linux.yaml
        $linuxFile = Join-Path $featureDir "meta.linux.yaml"
        if ($global:DOTFILES_PLATFORM -eq "wsl") {
            $wslFile = Join-Path $featureDir "meta.wsl.yaml"
            if (Test-Path $wslFile)   { $platformMetaFile = $wslFile }
            elseif (Test-Path $linuxFile) { $platformMetaFile = $linuxFile }
        } elseif (Test-Path $platformFile) {
            $platformMetaFile = $platformFile
        }

        if (-not (Test-Path $metaFile)) {
            Log-Error "Meta file not found: $metaFile"
            return $false
        }

        try {
            # ── Helper: read a yq list field from a file ──────────────────────
            $readYqList = {
                param($file, $expr)
                if (-not (Test-Path $file)) { return @() }
                $raw = & yq eval $expr $file 2>$null
                if ($LASTEXITCODE -ne 0 -or -not $raw) { return @() }
                return @($raw -split "`n" | Where-Object { $_ -and $_ -ne "null" })
            }

            # ── depends ───────────────────────────────────────────────────────
            $deps  = & $readYqList $metaFile '.depends[]'
            if ($platformMetaFile) {
                $deps += & $readYqList $platformMetaFile '.depends[]'
            }
            $uniqueDeps = @($deps | Select-Object -Unique | Where-Object { $_ } |
                ForEach-Object {
                    $canonicalDep = Canonical-Id-Normalize -Name $_ -DefaultSourceId $sourceId
                    $depParts = Canonical-Id-Parse $canonicalDep
                    if (-not (Source-Registry-IsAllowed -SourceId $depParts.SourceId -FeatureName $depParts.Name)) {
                        throw "dependency is not allowed by source registry: $canonicalDep"
                    }
                    $canonicalDep
                })
            $script:FeatureDeps[$feature] = $uniqueDeps

            # ── provides ──────────────────────────────────────────────────────
            $caps = & $readYqList $metaFile '.provides[].name'
            if ($platformMetaFile) {
                $caps += & $readYqList $platformMetaFile '.provides[].name'
            }
            foreach ($cap in ($caps | Select-Object -Unique | Where-Object { $_ })) {
                if (-not $script:Provides.ContainsKey($cap)) {
                    $script:Provides[$cap] = @()
                }
                $script:Provides[$cap] += $feature
            }

            # ── requires ──────────────────────────────────────────────────────
            $reqs = & $readYqList $metaFile '.requires[].name'
            if ($platformMetaFile) {
                $reqs += & $readYqList $platformMetaFile '.requires[].name'
            }
            $script:Requires[$feature] = @($reqs | Select-Object -Unique | Where-Object { $_ })

            # ── log ───────────────────────────────────────────────────────────
            if ($uniqueDeps.Count -gt 0) {
                Log-Info "  $feature depends on: $($uniqueDeps -join ', ')"
            }
            if ($caps.Count -gt 0) {
                Log-Info "  $feature provides: $($caps -join ', ')"
            }
            if ($script:Requires[$feature].Count -gt 0) {
                Log-Info "  $feature requires capabilities: $($script:Requires[$feature] -join ', ')"
            }
            if ($uniqueDeps.Count -eq 0 -and $caps.Count -eq 0 -and $script:Requires[$feature].Count -eq 0) {
                Log-Info "  $feature has no dependencies"
            }
        } catch {
            Log-Error "Failed to read metadata for ${feature}: $_"
            return $false
        }
    }

    return $true
}

# Invoke-InjectCapabilityDeps <DesiredFeatures>
# For each feature with requires[], locate providers in the desired feature set
# and add them as implicit entries in FeatureDeps.
# Returns $false if a required capability has no provider in the profile.
function Invoke-InjectCapabilityDeps {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$DesiredFeatures
    )

    foreach ($feature in $DesiredFeatures) {
        $caps = $script:Requires[$feature]
        if (-not $caps -or $caps.Count -eq 0) { continue }

        foreach ($cap in $caps) {
            $allProviders = @()
            if ($script:Provides.ContainsKey($cap)) {
                $allProviders = $script:Provides[$cap]
            }

            # Filter to providers present in the desired feature set
            $found = @($allProviders | Where-Object { $_ -in $DesiredFeatures })

            if ($found.Count -eq 0) {
                $knownList = if ($allProviders.Count -gt 0) { $allProviders -join ', ' } else { "(none registered)" }
                Log-Error "Feature '$feature' requires capability '$cap' but no provider is present in the profile."
                Log-Error "  Known providers: $knownList"
                return $false
            }

            # Inject as implicit depends (deduplicate)
            foreach ($p in $found) {
                if ($script:FeatureDeps[$feature] -notcontains $p) {
                    $script:FeatureDeps[$feature] = @($script:FeatureDeps[$feature]) + $p
                }
            }

            Log-Info "  $feature: capability '$cap' provided by: $($found -join ', ')"
        }
    }

    return $true
}

# Invoke-TopoSortDFS <Feature> <DesiredFeatures>
# Perform depth-first search for topological sorting.
function Invoke-TopoSortDFS {
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

# Resolve-Dependencies <DesiredFeatures>
# Resolve capability dependencies and return topologically sorted feature list.
function Resolve-Dependencies {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$DesiredFeatures
    )

    $script:Visited  = @{}
    $script:InStack  = @{}
    $script:Sorted   = @()

    Log-Info "Resolving dependencies..."

    # Inject implicit deps derived from requires/provides into FeatureDeps
    if (-not (Invoke-InjectCapabilityDeps -DesiredFeatures $DesiredFeatures)) {
        return $null
    }

    # Sort all features
    foreach ($feature in $DesiredFeatures) {
        if (-not (Invoke-TopoSortDFS -Feature $feature -DesiredFeatures $DesiredFeatures)) {
            return $null
        }
    }

    Log-Success "Install order (canonical IDs): $($script:Sorted -join ' ')"
    return $script:Sorted
}
