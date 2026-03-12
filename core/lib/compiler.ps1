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
            $target = $ResourceObj.PSObject.Properties['target']?.Value
            $path   = $ResourceObj.PSObject.Properties['path']?.Value
            $p      = if ($target) { $target } elseif ($path) { $path } else { "unknown" }
            return "fs:$([System.IO.Path]::GetFileName($p))"
        }
        default {
            return "${Kind}:unknown"
        }
    }
}

# _Compiler-ProfileVersion <ProfileFile> <CanonicalId>
# Extract version hint for a feature from its profile YAML entry.
# Tries the canonical ID key first, then falls back to the bare name.
# Returns $null if not found or no version is set.
function _Compiler-ProfileVersion {
    param(
        [Parameter(Mandatory=$true)] [string]$ProfileFile,
        [Parameter(Mandatory=$true)] [string]$CanonicalId
    )

    try {
        # Try canonical ID (e.g. "tools/node")
        $val = Get-Content $ProfileFile -Raw |
               & yq eval ".features[\"${CanonicalId}\"].version // \"\"" - 2>$null
        if ($LASTEXITCODE -eq 0 -and
            -not [string]::IsNullOrWhiteSpace($val) -and
            $val -ne "null" -and $val -ne "") {
            return $val
        }

        # Fallback: bare name (e.g. "node")
        $bareName = if ($CanonicalId -match '/') { $CanonicalId -replace '^[^/]+/', '' } else { $CanonicalId }
        if ($bareName -ne $CanonicalId) {
            $val = Get-Content $ProfileFile -Raw |
                   & yq eval ".features[\"${bareName}\"].version // \"\"" - 2>$null
            if ($LASTEXITCODE -eq 0 -and
                -not [string]::IsNullOrWhiteSpace($val) -and
                $val -ne "null" -and $val -ne "") {
                return $val
            }
        }
    } catch { }

    return $null
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

            # Embed version hint from profile if available
            $profileFile   = $script:CompilerProfileFile   ?? ""
            $canonicalIdCtx = $script:CompilerCanonicalId  ?? ""
            if ($profileFile -ne "" -and $canonicalIdCtx -ne "" -and (Test-Path $profileFile)) {
                $versionHint = _Compiler-ProfileVersion -ProfileFile $profileFile -CanonicalId $canonicalIdCtx
                if ($versionHint) { $updated['version'] = $versionHint }
            }
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

# Script-scoped context set by Invoke-FeatureCompilerRun so that
# _Compiler-ResolveResource can embed profile version hints without signature changes.
$script:CompilerProfileFile = ""
$script:CompilerCanonicalId = ""

# Invoke-FeatureCompilerRun <FeatureIndexJson> <SortedFeatures> [<ProfileFile>]
# Compile DesiredResourceGraph from Feature Index and resolved feature order.
# Returns DesiredResourceGraph JSON string, or $null on error.
#
# For mode:script features: entry with empty resources array.
# For mode:declarative features: resources expanded with desired_backend.
# Optional ProfileFile: when supplied, runtime resources embed version hints.
function Invoke-FeatureCompilerRun {
    param(
        [Parameter(Mandatory=$true)]  [string]   $FeatureIndexJson,
        [Parameter(Mandatory=$true)]  [string[]] $SortedFeatures,
        [Parameter(Mandatory=$false)] [string]   $ProfileFile = ""
    )

    $script:CompilerProfileFile = $ProfileFile

    $index    = $FeatureIndexJson | ConvertFrom-Json
    $features = [ordered]@{}

    foreach ($canonicalId in $SortedFeatures) {
        # Expose the current canonical ID for _Compiler-ResolveResource
        $script:CompilerCanonicalId = $canonicalId

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
