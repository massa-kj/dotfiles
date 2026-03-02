# -----------------------------------------------------------------------------
# Module: planner (PowerShell)
#
# Responsibility:
#   PURE decision engine. Converts (profile, state, policy) into a structured
#   plan object. Never executes, never modifies state.
#
# Public API:
#   Invoke-PlannerRun <ProfileFile> <SortedFeatures>  → plan JSON string
#
# See bash planner.sh for full design notes.
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This module uses public state functions (State-*) as READ-ONLY inputs.

# Valid resource kinds. Anything else causes a "blocked" classification.
$script:PlannerValidKinds = @("package", "runtime", "fs")

# ── Profile helpers ───────────────────────────────────────────────────────────

function _Planner-ProfileVersion {
    <#
    .SYNOPSIS Extract .features.<feature>.version from a profile YAML string.
    Returns $null if not set.
    #>
    param([string]$ProfileData, [string]$Feature)

    try {
        $val = $ProfileData | & yq eval ".features.${Feature}.version // `"`"" - 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($val)) {
            return $val
        }
    } catch { }
    return $null
}

# ── State helpers (read-only via public API) ──────────────────────────────────

function _Planner-StateRuntimeVersion {
    <#
    .SYNOPSIS Get the runtime resource version for a feature from state. Returns $null if none.
    #>
    param([string]$Feature)

    $resources = @(State-QueryResources -Feature $Feature)
    $rt = $resources | Where-Object { $_.kind -eq "runtime" } | Select-Object -First 1
    if ($rt -and $rt.version) { return [string]$rt.version }
    return $null
}

function _Planner-StateHasUnknownKind {
    <#
    .SYNOPSIS Return $true if the feature has any resource with an unrecognised kind.
    #>
    param([string]$Feature)

    $resources = @(State-QueryResources -Feature $Feature)
    foreach ($r in $resources) {
        if ($r.kind -notin $script:PlannerValidKinds) { return $true }
    }
    return $false
}

function _Planner-StateUnknownKindsList {
    <#
    .SYNOPSIS Return a comma-separated list of unrecognised resource kinds.
    #>
    param([string]$Feature)

    $resources = @(State-QueryResources -Feature $Feature)
    $unknown = $resources | Where-Object { $_.kind -notin $script:PlannerValidKinds } |
        Select-Object -ExpandProperty kind | Sort-Object -Unique
    return ($unknown -join ", ")
}

# ── Phase 1: Diff ─────────────────────────────────────────────────────────────

function _Planner-Diff {
    <#
    .SYNOPSIS Compare desired features (profile) against current state.
    Returns an array of diff objects.
    #>
    param([string]$ProfileData, [string[]]$SortedFeatures)

    $diff = @()

    # Desired features in sorted dependency order
    foreach ($feature in $SortedFeatures) {
        $inState      = State-HasFeature -Feature $feature
        $versionDesired  = _Planner-ProfileVersion -ProfileData $ProfileData -Feature $feature
        $versionInstalled = $null
        $hasBlocked   = $false
        $blockedReason = $null

        if ($inState) {
            $rv = _Planner-StateRuntimeVersion -Feature $feature
            if ($rv) { $versionInstalled = $rv }

            if (_Planner-StateHasUnknownKind -Feature $feature) {
                $hasBlocked    = $true
                $kinds         = _Planner-StateUnknownKindsList -Feature $feature
                $blockedReason = "unknown resource kind: $kinds"
            }
        }

        $diff += [PSCustomObject]@{
            feature               = $feature
            in_profile            = $true
            in_state              = $inState
            version_desired       = $versionDesired
            version_installed     = $versionInstalled
            has_blocked_resources = $hasBlocked
            blocked_reason        = $blockedReason
        }
    }

    # Installed features not in profile (candidates for destroy)
    $installedFeatures = @(State-ListFeatures)
    foreach ($feature in $installedFeatures) {
        if ($feature -in $SortedFeatures) { continue }

        $diff += [PSCustomObject]@{
            feature               = $feature
            in_profile            = $false
            in_state              = $true
            version_desired       = $null
            version_installed     = $null
            has_blocked_resources = $false
            blocked_reason        = $null
        }
    }

    return $diff
}

# ── Phase 2: Classification ───────────────────────────────────────────────────

function _Planner-Classify {
    <#
    .SYNOPSIS Apply the decision table to each diff entry.
    Returns an array of classified objects.
    #>
    param([object[]]$Diff)

    $classified = @()

    foreach ($entry in $Diff) {
        if ($entry.has_blocked_resources) {
            $classified += [PSCustomObject]@{
                feature        = $entry.feature
                classification = "blocked"
                reason         = ($entry.blocked_reason ?? "unknown resource kind in state")
            }
        } elseif ($entry.in_profile -and (-not $entry.in_state)) {
            $classified += [PSCustomObject]@{
                feature         = $entry.feature
                classification  = "create"
                desired_version = $entry.version_desired
            }
        } elseif ((-not $entry.in_profile) -and $entry.in_state) {
            $classified += [PSCustomObject]@{
                feature        = $entry.feature
                classification = "destroy"
            }
        } elseif ($entry.in_profile -and $entry.in_state) {
            if ($entry.version_desired -and $entry.version_desired -ne $entry.version_installed) {
                $classified += [PSCustomObject]@{
                    feature        = $entry.feature
                    classification = "replace"
                    from_version   = $entry.version_installed
                    to_version     = $entry.version_desired
                }
            } else {
                $classified += [PSCustomObject]@{
                    feature        = $entry.feature
                    classification = "noop"
                }
            }
        } else {
            # Unreachable, but table must be total
            $classified += [PSCustomObject]@{
                feature        = $entry.feature
                classification = "noop"
            }
        }
    }

    return $classified
}

# ── Phase 3: Decision ─────────────────────────────────────────────────────────

function _Planner-Decide {
    <#
    .SYNOPSIS Apply ordering rules and produce the final plan object.
    Ordering (PLANNER_SPEC §6): destroy (reversed) → replace → create.
    Returns a PSCustomObject that can be serialised to JSON.
    #>
    param([object[]]$Classified)

    $destroys  = @($Classified | Where-Object { $_.classification -eq "destroy"  })
    $replaces  = @($Classified | Where-Object { $_.classification -eq "replace"  })
    $creates   = @($Classified | Where-Object { $_.classification -eq "create"   })
    $blocked   = @($Classified | Where-Object { $_.classification -eq "blocked"  })
    $noops     = @($Classified | Where-Object { $_.classification -eq "noop"     })

    # Reverse destroy order
    [array]::Reverse($destroys)

    $actions = @()

    foreach ($d in $destroys) {
        $actions += [PSCustomObject]@{
            feature   = $d.feature
            operation = "destroy"
            details   = [PSCustomObject]@{}
        }
    }
    foreach ($r in $replaces) {
        $actions += [PSCustomObject]@{
            feature   = $r.feature
            operation = "replace"
            details   = [PSCustomObject]@{
                from_version   = $r.from_version
                to_version     = $r.to_version
                config_version = $r.to_version
            }
        }
    }
    foreach ($c in $creates) {
        $actions += [PSCustomObject]@{
            feature   = $c.feature
            operation = "create"
            details   = [PSCustomObject]@{
                config_version = $c.desired_version
            }
        }
    }

    $blockedList = @($blocked | ForEach-Object {
        [PSCustomObject]@{
            feature = $_.feature
            reason  = ($_.reason ?? "unknown resource kind in state")
        }
    })

    return [PSCustomObject]@{
        actions = $actions
        blocked = $blockedList
        summary = [PSCustomObject]@{
            create          = $creates.Count
            destroy         = $destroys.Count
            replace         = $replaces.Count
            replace_backend = 0
            strengthen      = 0
            noop            = $noops.Count
            blocked         = $blocked.Count
        }
    }
}

# ── Public API ────────────────────────────────────────────────────────────────

function Invoke-PlannerRun {
    <#
    .SYNOPSIS Full planning pipeline: diff → classify → decide.
    Returns the plan as a JSON string.
    Reads $script:StateData via public State-* functions (read-only).
    #>
    param(
        [Parameter(Mandatory=$true)] [string]$ProfileFile,
        [Parameter(Mandatory=$true)] [string[]]$SortedFeatures
    )

    if (-not (Test-Path $ProfileFile)) {
        Log-Error "Invoke-PlannerRun: profile file not found: $ProfileFile"
        throw "Profile not found: $ProfileFile"
    }

    $profileData = Get-Content $ProfileFile -Raw

    $diff        = _Planner-Diff       -ProfileData $profileData -SortedFeatures $SortedFeatures
    $classified  = _Planner-Classify   -Diff $diff
    $plan        = _Planner-Decide     -Classified $classified

    return ($plan | ConvertTo-Json -Depth 10 -Compress:$false)
}
