# -----------------------------------------------------------------------------
# Module: planner (PowerShell)
#
# Responsibility:
#   PURE decision engine. Converts (desired_resource_graph, state) into a
#   structured plan object describing what the executor should do.
#   Never executes anything.
#
# Public API:
#   Invoke-PlannerRun <DrgJson> <SortedFeatures>  → plan JSON string
#
# Internal phases (each PURE function):
#   _Planner-Diff       drg × state → diff array
#   _Planner-Classify   diff array  → classified array
#   _Planner-Decide     classified  → plan PSCustomObject
#
# Inputs:
#   DrgJson        — DesiredResourceGraph JSON (produced by FeatureCompiler)
#   SortedFeatures — topologically sorted canonical feature IDs
#   State-*        — public state API (read-only)
#
# Planner must NOT receive profile or policy directly.
# Backend resolution (desired_backend per resource) is already in DrgJson.
#
# Plan JSON schema:
#   {
#     "actions": [
#       {"feature": "core/git",   "operation": "create",   "details": {}},
#       {"feature": "core/node",  "operation": "replace",  "details": {}},
#       {"feature": "core/tmux",  "operation": "strengthen",
#        "details": {"add_resources": [{"kind": "fs", "id": "fs:tmux.conf"}]}}
#     ],
#     "noops":   [{"feature": "core/bash"}],
#     "blocked": [{"feature": "user/legacy", "reason": "unknown resource kind: registry"}],
#     "summary": {"create":1, "destroy":0, "replace":1, "replace_backend":0,
#                 "strengthen":1, "noop":1, "blocked":0}
#   }
#
# Classification table:
#   in_desired=false, in_state=true                              → destroy
#   in_desired=true,  in_state=false                             → create
#   in_desired=true,  in_state=true, desired_resources empty     → noop  (script feature)
#   in_desired=true,  in_state=true, incompatible resource change → replace
#   in_desired=true,  in_state=true, backend mismatch only       → replace_backend
#   in_desired=true,  in_state=true, strict superset + compat    → strengthen
#   in_desired=true,  in_state=true, identical resources         → noop
#   unknown resource kind in desired or state                    → blocked
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Valid resource kinds.  Anything else causes a "blocked" classification.
$script:PlannerValidKinds = @("package", "runtime", "fs")

# ── Semantic key helpers ──────────────────────────────────────────────────────

# _Planner-DesiredSemanticKey <Res>
# Returns a stable semantic key for a desired resource (from DRG):
#   package → "pkg:<name>"
#   runtime → "rt:<name>"
#   fs      → "fs:<basename(target or path)>"
function _Planner-DesiredSemanticKey {
    param([Parameter(Mandatory=$true)] [object]$Res)

    $kind = $Res.PSObject.Properties['kind']?.Value
    switch ($kind) {
        "package" { return "pkg:" + ($Res.PSObject.Properties['name']?.Value ?? "?") }
        "runtime" { return "rt:"  + ($Res.PSObject.Properties['name']?.Value ?? "?") }
        "fs" {
            $target = $Res.PSObject.Properties['target']?.Value
            $path   = $Res.PSObject.Properties['path']?.Value
            $p      = if ($target) { $target } elseif ($path) { $path } else { "" }
            return "fs:" + [System.IO.Path]::GetFileName($p)
        }
        default { return "other:$kind" }
    }
}

# _Planner-StateSemanticKey <Res>
# Returns a stable semantic key for a state resource:
#   package → "pkg:<package.name>"
#   runtime → "rt:<runtime.name>"
#   fs      → "fs:<basename(fs.path)>"
function _Planner-StateSemanticKey {
    param([Parameter(Mandatory=$true)] [object]$Res)

    $kind = $Res.PSObject.Properties['kind']?.Value
    switch ($kind) {
        "package" {
            $pkg  = $Res.PSObject.Properties['package']?.Value
            $name = if ($pkg) { $pkg.PSObject.Properties['name']?.Value } else { $null }
            return "pkg:" + ($name ?? "?")
        }
        "runtime" {
            $rt   = $Res.PSObject.Properties['runtime']?.Value
            $name = if ($rt) { $rt.PSObject.Properties['name']?.Value } else { $null }
            return "rt:" + ($name ?? "?")
        }
        "fs" {
            $fs = $Res.PSObject.Properties['fs']?.Value
            $p  = if ($fs) { $fs.PSObject.Properties['path']?.Value ?? "" } else { "" }
            return "fs:" + [System.IO.Path]::GetFileName($p)
        }
        default { return "other:$kind" }
    }
}

# _Planner-CheckResourceCompat <DesiredRes> <StateRes>
# Compare one desired resource against its matched state resource.
# Returns one of: "compatible", "backend_mismatch", "version_mismatch", "incompatible".
function _Planner-CheckResourceCompat {
    param(
        [Parameter(Mandatory=$true)] [object]$DesiredRes,
        [Parameter(Mandatory=$true)] [object]$StateRes
    )

    $kind = $DesiredRes.PSObject.Properties['kind']?.Value
    switch ($kind) {
        "package" {
            $dBackend = $DesiredRes.PSObject.Properties['desired_backend']?.Value ?? "?"
            $sBackend = $StateRes.PSObject.Properties['backend']?.Value            ?? "?"
            if ($dBackend -ne $sBackend) { return "backend_mismatch" }
            return "compatible"
        }
        "runtime" {
            $dBackend = $DesiredRes.PSObject.Properties['desired_backend']?.Value ?? "?"
            $sBackend = $StateRes.PSObject.Properties['backend']?.Value            ?? "?"
            if ($dBackend -ne $sBackend) { return "backend_mismatch" }

            $dVer = $DesiredRes.PSObject.Properties['version']?.Value
            if ($dVer -and $dVer -ne "") {
                $rt   = $StateRes.PSObject.Properties['runtime']?.Value
                $sVer = if ($rt) { $rt.PSObject.Properties['version']?.Value } else { $null }
                if ($dVer -ne ($sVer ?? "")) { return "version_mismatch" }
            }
            return "compatible"
        }
        "fs" {
            $dTarget = $DesiredRes.PSObject.Properties['target']?.Value ?? `
                       $DesiredRes.PSObject.Properties['path']?.Value   ?? ""
            $fs    = $StateRes.PSObject.Properties['fs']?.Value
            $sPath = if ($fs) { $fs.PSObject.Properties['path']?.Value ?? "" } else { "" }
            if ($dTarget -ne $sPath) { return "incompatible" }

            $dEt = $DesiredRes.PSObject.Properties['entry_type']?.Value
            if ($dEt -and $dEt -ne "") {
                $sEt = if ($fs) { $fs.PSObject.Properties['entry_type']?.Value } else { $null }
                if ($dEt -ne ($sEt ?? "")) { return "incompatible" }
            }

            $dOp = $DesiredRes.PSObject.Properties['op']?.Value ?? "link"
            $sOp = if ($fs) { $fs.PSObject.Properties['op']?.Value ?? "link" } else { "link" }
            if ($dOp -ne $sOp) { return "incompatible" }

            return "compatible"
        }
        default { return "compatible" }
    }
}

# ── State helpers (read-only) ─────────────────────────────────────────────────

function _Planner-StateHasUnknownKind {
    param([string]$Feature)
    $resources = @(State-QueryResources -Feature $Feature)
    foreach ($r in $resources) {
        if ($r.PSObject.Properties['kind']?.Value -notin $script:PlannerValidKinds) { return $true }
    }
    return $false
}

function _Planner-StateUnknownKindsList {
    param([string]$Feature)
    $resources = @(State-QueryResources -Feature $Feature)
    $unknown   = @($resources | Where-Object {
        $_.PSObject.Properties['kind']?.Value -notin $script:PlannerValidKinds
    } | Select-Object -ExpandProperty kind | Sort-Object -Unique)
    return ($unknown -join ", ")
}

# ── Phase 1: Diff ─────────────────────────────────────────────────────────────

# _Planner-Diff <DrgJson> <SortedFeatures>
# Compare desired features (DRG) against current state.
# Returns an array of diff objects.
function _Planner-Diff {
    param(
        [Parameter(Mandatory=$true)] [string]   $DrgJson,
        [Parameter(Mandatory=$true)] [string[]] $SortedFeatures
    )

    $drg  = $DrgJson | ConvertFrom-Json
    $diff = @()

    # ── Desired features in sorted dependency order ──
    foreach ($feature in $SortedFeatures) {
        $inState = State-HasFeature -Feature $feature

        # Extract desired resources from DRG
        $drgFeature       = $drg.features.PSObject.Properties[$feature]?.Value
        $desiredResources = @()
        if ($drgFeature -and $drgFeature.PSObject.Properties['resources']?.Value) {
            $desiredResources = @($drgFeature.resources)
        }
        $desiredCount = $desiredResources.Count

        # Extract state resources
        $stateResources = @()
        if ($inState) {
            $stateResources = @(State-QueryResources -Feature $feature)
        }

        # Check for unknown resource kinds
        $hasBlocked    = $false
        $blockedReason = $null

        $unkDesired = @($desiredResources | Where-Object {
            $_.PSObject.Properties['kind']?.Value -notin $script:PlannerValidKinds
        })
        if ($unkDesired.Count -gt 0) {
            $kinds         = ($unkDesired | ForEach-Object { $_.PSObject.Properties['kind']?.Value } | Sort-Object -Unique) -join ", "
            $hasBlocked    = $true
            $blockedReason = "unknown resource kind: $kinds"
        }

        if ($inState -and (-not $hasBlocked)) {
            $unkState = @($stateResources | Where-Object {
                $_.PSObject.Properties['kind']?.Value -notin $script:PlannerValidKinds
            })
            if ($unkState.Count -gt 0) {
                $kinds         = ($unkState | ForEach-Object { $_.PSObject.Properties['kind']?.Value } | Sort-Object -Unique) -join ", "
                $hasBlocked    = $true
                $blockedReason = "unknown resource kind in state: $kinds"
            }
        }

        $diff += [PSCustomObject]@{
            feature                = $feature
            in_desired             = $true
            in_state               = $inState
            desired_resource_count = $desiredCount
            desired_resources      = $desiredResources
            state_resources        = $stateResources
            has_blocked_resources  = $hasBlocked
            blocked_reason         = $blockedReason
        }
    }

    # ── Installed features not in desired (candidates for destroy) ──
    $installedFeatures = @(State-ListFeatures)
    foreach ($installedFeat in $installedFeatures) {
        if ($SortedFeatures -contains $installedFeat) { continue }

        $diff += [PSCustomObject]@{
            feature                = $installedFeat
            in_desired             = $false
            in_state               = $true
            desired_resource_count = 0
            desired_resources      = @()
            state_resources        = @()
            has_blocked_resources  = $false
            blocked_reason         = $null
        }
    }

    return $diff
}

# ── Phase 2: Classification ───────────────────────────────────────────────────

# _Planner-Classify <Diff>
# Apply the decision table to each diff entry.
# Returns an array of classified objects.
function _Planner-Classify {
    param([Parameter(Mandatory=$true)] [object[]] $Diff)

    $classified = @()

    foreach ($entry in $Diff) {
        if ($entry.has_blocked_resources) {
            $classified += [PSCustomObject]@{
                feature        = $entry.feature
                classification = "blocked"
                reason         = ($entry.blocked_reason ?? "unknown resource kind")
            }

        } elseif ($entry.in_desired -and (-not $entry.in_state)) {
            $classified += [PSCustomObject]@{
                feature        = $entry.feature
                classification = "create"
            }

        } elseif ((-not $entry.in_desired) -and $entry.in_state) {
            $classified += [PSCustomObject]@{
                feature        = $entry.feature
                classification = "destroy"
            }

        } elseif ($entry.in_desired -and $entry.in_state) {

            if ($entry.desired_resource_count -eq 0) {
                # Script feature: classify by presence only
                $classified += [PSCustomObject]@{
                    feature        = $entry.feature
                    classification = "noop"
                }
            } else {
                # Build semantic key maps
                $dKeyed = @{}
                foreach ($r in @($entry.desired_resources)) {
                    $key = _Planner-DesiredSemanticKey -Res $r
                    $dKeyed[$key] = $r
                }
                $sKeyed = @{}
                foreach ($r in @($entry.state_resources)) {
                    $key = _Planner-StateSemanticKey -Res $r
                    $sKeyed[$key] = $r
                }

                $dKeys = @($dKeyed.Keys)
                $sKeys = @($sKeyed.Keys)

                # Set operations
                $common = @($dKeys | Where-Object { $sKeys -contains $_ })
                $dOnly  = @($dKeys | Where-Object { $sKeys -notcontains $_ })
                $sOnly  = @($sKeys | Where-Object { $dKeys -notcontains $_ })

                # Compatibility of common resources
                $hasInc = $false   # has incompatible (non-backend) change
                $hasBm  = $false   # has backend mismatch only

                foreach ($k in $common) {
                    $compat = _Planner-CheckResourceCompat -DesiredRes $dKeyed[$k] -StateRes $sKeyed[$k]
                    if     ($compat -eq "backend_mismatch") { $hasBm  = $true }
                    elseif ($compat -ne "compatible")       { $hasInc = $true }
                }

                if ($hasInc -or $sOnly.Count -gt 0) {
                    # Incompatible mutation or state has resources removed from desired
                    $classified += [PSCustomObject]@{
                        feature        = $entry.feature
                        classification = "replace"
                    }
                } elseif ($hasBm) {
                    $classified += [PSCustomObject]@{
                        feature        = $entry.feature
                        classification = "replace_backend"
                    }
                } elseif ($dOnly.Count -gt 0) {
                    # All state resources present in desired, all common compatible, desired has extras
                    $addResources = @($dOnly | ForEach-Object {
                        $r = $dKeyed[$_]
                        [PSCustomObject]@{
                            kind = $r.PSObject.Properties['kind']?.Value
                            id   = $r.PSObject.Properties['id']?.Value ?? $r.PSObject.Properties['kind']?.Value
                        }
                    })
                    $classified += [PSCustomObject]@{
                        feature        = $entry.feature
                        classification = "strengthen"
                        add_resources  = $addResources
                    }
                } else {
                    $classified += [PSCustomObject]@{
                        feature        = $entry.feature
                        classification = "noop"
                    }
                }
            }

        } else {
            # Unreachable, but the table must be total
            $classified += [PSCustomObject]@{
                feature        = $entry.feature
                classification = "noop"
            }
        }
    }

    return $classified
}

# ── Phase 3: Decision ─────────────────────────────────────────────────────────

# _Planner-Decide <Classified>
# Apply ordering rules and produce the final plan object.
# Ordering: destroy (reversed) → replace → replace_backend → strengthen → create
function _Planner-Decide {
    param([Parameter(Mandatory=$true)] [object[]] $Classified)

    $destroys        = @($Classified | Where-Object { $_.classification -eq "destroy"         })
    $replaces        = @($Classified | Where-Object { $_.classification -eq "replace"         })
    $replaceBackends = @($Classified | Where-Object { $_.classification -eq "replace_backend" })
    $strengthens     = @($Classified | Where-Object { $_.classification -eq "strengthen"      })
    $creates         = @($Classified | Where-Object { $_.classification -eq "create"          })
    $blocked         = @($Classified | Where-Object { $_.classification -eq "blocked"         })
    $noops           = @($Classified | Where-Object { $_.classification -eq "noop"            })

    # Reverse destroy order (uninstall in reverse dependency order)
    [array]::Reverse($destroys)

    $actions = @()

    foreach ($d  in $destroys)        { $actions += [PSCustomObject]@{ feature = $d.feature;  operation = "destroy";         details = [PSCustomObject]@{} } }
    foreach ($r  in $replaces)        { $actions += [PSCustomObject]@{ feature = $r.feature;  operation = "replace";         details = [PSCustomObject]@{} } }
    foreach ($rb in $replaceBackends) { $actions += [PSCustomObject]@{ feature = $rb.feature; operation = "replace_backend"; details = [PSCustomObject]@{} } }
    foreach ($s  in $strengthens) {
        $addRes = if ($s.PSObject.Properties['add_resources']?.Value) { @($s.add_resources) } else { @() }
        $actions += [PSCustomObject]@{
            feature   = $s.feature
            operation = "strengthen"
            details   = [PSCustomObject]@{ add_resources = $addRes }
        }
    }
    foreach ($c  in $creates)         { $actions += [PSCustomObject]@{ feature = $c.feature;  operation = "create";          details = [PSCustomObject]@{} } }

    $blockedList = @($blocked | ForEach-Object {
        [PSCustomObject]@{ feature = $_.feature; reason = ($_.reason ?? "unknown resource kind") }
    })
    $noopList = @($noops | ForEach-Object { [PSCustomObject]@{ feature = $_.feature } })

    return [PSCustomObject]@{
        actions = $actions
        blocked = $blockedList
        noops   = $noopList
        summary = [PSCustomObject]@{
            create          = $creates.Count
            destroy         = $destroys.Count
            replace         = $replaces.Count
            replace_backend = $replaceBackends.Count
            strengthen      = $strengthens.Count
            noop            = $noops.Count
            blocked         = $blocked.Count
        }
    }
}

# ── Public API ────────────────────────────────────────────────────────────────

# Invoke-PlannerRun <DrgJson> <SortedFeatures>
# Full planning pipeline: diff → classify → decide.
# Returns the plan as a JSON string, or throws on error.
#
# Reads state via State-HasFeature / State-ListFeatures / State-QueryResources (read-only).
function Invoke-PlannerRun {
    param(
        [Parameter(Mandatory=$true)] [string]   $DrgJson,
        [Parameter(Mandatory=$true)] [string[]] $SortedFeatures
    )

    if ([string]::IsNullOrWhiteSpace($DrgJson)) {
        Log-Error "Invoke-PlannerRun: DrgJson is required"
        throw "Invoke-PlannerRun: DrgJson is required"
    }

    $diff       = _Planner-Diff     -DrgJson $DrgJson -SortedFeatures $SortedFeatures
    $classified = _Planner-Classify -Diff $diff
    $plan       = _Planner-Decide   -Classified $classified

    return ($plan | ConvertTo-Json -Depth 10 -Compress:$false)
}
