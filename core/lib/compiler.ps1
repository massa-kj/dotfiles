# -----------------------------------------------------------------------------
# Module: compiler (FeatureCompiler, PowerShell)
#
# Responsibility:
#   Compile the DesiredResourceGraph from Feature Index + resolved feature order
#   and policy (desired_backend resolution).
#
# Public API (Stable):
#   Invoke-FeatureCompilerRun <FeatureIndexJson> <SortedFeatures>
#   Returns DesiredResourceGraph JSON string, or $null on error.
#
# Contract:
#   - mode:script     → entry with empty resources array
#   - mode:declarative → resources expanded with desired_backend from policy
#   - Declarative validation: error if no resources, error if install.ps1 present
#
# JSON schema: see docs/specs/data/desired_resource_graph.md
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1, logger.ps1, source_registry.ps1, and
# backend_registry.ps1 to be loaded by the caller.

# Lazily source backend_registry if not already loaded
if (-not (Get-Command Resolve-BackendFor -ErrorAction SilentlyContinue)) {
    . "$env:DOTFILES_ROOT\core\lib\backend_registry.ps1"
}

# _Compiler-ResourceId <Kind> <ResourceObj>
# Derive a stable resource id from a resource object.
function _Compiler-ResourceId {
    param(
        [Parameter(Mandatory=$true)] [string]$Kind,
        [Parameter(Mandatory=$true)] [object]$ResourceObj
    )

    # Use explicit id if present
    $existingId = $ResourceObj.PSObject.Properties['id']?.Value
    if ($existingId -and $existingId -ne "null") { return $existingId }

    switch ($Kind) {
        "package" {
            $name = $ResourceObj.PSObject.Properties['name']?.Value
            return "package:$name"
        }
        "runtime" {
            $name = $ResourceObj.PSObject.Properties['name']?.Value
            return "runtime:$name"
        }
        "fs" {
            $path = $ResourceObj.PSObject.Properties['path']?.Value
            return "fs:$(Split-Path $path -Leaf)"
        }
        default {
            return "${Kind}:unknown"
        }
    }
}

# _Compiler-ResolveResource <CanonicalId> <ResourceObj>
# Add desired_backend and id to a resource object (as new PSCustomObject).
function _Compiler-ResolveResource {
    param(
        [Parameter(Mandatory=$true)] [string]$CanonicalId,
        [Parameter(Mandatory=$true)] [object]$ResourceObj
    )

    $kind = $ResourceObj.PSObject.Properties['kind']?.Value
    if (-not $kind -or $kind -eq "null") {
        throw "resource missing 'kind' in $CanonicalId"
    }

    $resourceId = _Compiler-ResourceId -Kind $kind -ResourceObj $ResourceObj

    # Build a copy of the resource as an ordered hashtable
    $updated = [ordered]@{}
    foreach ($prop in $ResourceObj.PSObject.Properties) {
        $updated[$prop.Name] = $prop.Value
    }
    $updated['id'] = $resourceId

    switch ($kind) {
        "package" {
            $name = $ResourceObj.PSObject.Properties['name']?.Value
            $backend = Resolve-BackendFor -Kind "package" -Name $name 2>$null
            if (-not $backend) { $backend = "unknown" }
            $updated['desired_backend'] = $backend
        }
        "runtime" {
            $name = $ResourceObj.PSObject.Properties['name']?.Value
            $backend = Resolve-BackendFor -Kind "runtime" -Name $name 2>$null
            if (-not $backend) { $backend = "unknown" }
            $updated['desired_backend'] = $backend
        }
        "fs" {
            # fs resources have no backend
        }
        default {
            throw "unknown resource kind '$kind' in $CanonicalId"
        }
    }

    return $updated
}

# Invoke-FeatureCompilerRun <FeatureIndexJson> <SortedFeatures>
# Compile DesiredResourceGraph from Feature Index and resolved feature order.
# Returns DesiredResourceGraph JSON string, or $null on error.
#
# For mode:script features: entry with empty resources array.
# For mode:declarative features: resources expanded with desired_backend.
function Invoke-FeatureCompilerRun {
    param(
        [Parameter(Mandatory=$true)] [string]$FeatureIndexJson,
        [Parameter(Mandatory=$true)] [string[]]$SortedFeatures
    )

    $index    = $FeatureIndexJson | ConvertFrom-Json
    $features = [ordered]@{}

    foreach ($canonicalId in $SortedFeatures) {
        $prop = $index.features.PSObject.Properties[$canonicalId]
        if ($null -eq $prop) {
            Log-Error "Invoke-FeatureCompilerRun: feature not found in index: $canonicalId"
            return $null
        }
        $entry = $prop.Value
        $mode  = $entry.mode

        $resources = @()

        if ($mode -eq "declarative") {
            # ── Declarative validation ─────────────────────────────────────
            $sourceDir = $entry.source_dir

            # Must not have install.ps1 or uninstall.ps1
            $hasInstall   = Test-Path (Join-Path $sourceDir "install.ps1")
            $hasUninstall = Test-Path (Join-Path $sourceDir "uninstall.ps1")
            if ($hasInstall -or $hasUninstall) {
                Log-Error "Invoke-FeatureCompilerRun: declarative feature must not have install.ps1/uninstall.ps1: $canonicalId"
                return $null
            }

            # spec must exist with at least one resource
            $specResources = @()
            if ($entry.spec -and $entry.spec.resources) {
                $specResources = @($entry.spec.resources)
            }
            if ($specResources.Count -eq 0) {
                Log-Error "Invoke-FeatureCompilerRun: declarative feature has no resources defined: $canonicalId"
                return $null
            }

            # ── Expand resources with desired_backend ──────────────────────
            foreach ($res in $specResources) {
                try {
                    $resolved  = _Compiler-ResolveResource -CanonicalId $canonicalId -ResourceObj $res
                    $resources = @($resources) + $resolved
                } catch {
                    Log-Error "Invoke-FeatureCompilerRun: failed to resolve resource in ${canonicalId}: $_"
                    return $null
                }
            }
        }

        $features[$canonicalId] = [ordered]@{ resources = $resources }
    }

    $drg = [ordered]@{
        schema_version = 1
        features       = $features
    }

    return $drg | ConvertTo-Json -Depth 20 -Compress
}
