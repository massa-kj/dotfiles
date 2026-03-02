# -----------------------------------------------------------------------------
# Module: executor (PowerShell)
#
# Responsibility:
#   IMPURE executor. Receives a plan JSON string from planner and executes it.
#   Calls feature scripts, manages state after each successful operation.
#
# Public API:
#   Invoke-ExecutorRun <PlanJson>
#
# See bash executor.sh for full design notes.
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Internal helpers ──────────────────────────────────────────────────────────

function _Executor-RunScript {
    <#
    .SYNOPSIS Run a feature script. Returns $true on success, $false on failure.
    Does NOT throw; caller decides whether to abort.
    #>
    param(
        [Parameter(Mandatory=$true)] [string]$ScriptPath,
        [hashtable]$EnvVars = @{}
    )

    if (-not (Test-Path $ScriptPath)) {
        Log-Error "executor: script not found: $ScriptPath"
        return $false
    }

    try {
        # Set extra env vars for the subprocess
        $saved = @{}
        foreach ($kv in $EnvVars.GetEnumerator()) {
            $saved[$kv.Key] = [System.Environment]::GetEnvironmentVariable($kv.Key)
            [System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value)
        }

        & $ScriptPath
        $exitCode = $LASTEXITCODE

        foreach ($kv in $saved.GetEnumerator()) {
            [System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value)
        }

        return ($exitCode -eq 0 -or $null -eq $exitCode)
    } catch {
        Log-Error "executor: script raised exception: $ScriptPath — $_"
        return $false
    }
}

function _Executor-Destroy {
    param([string]$Feature)

    $script = Join-Path (Join-Path $env:DOTFILES_FEATURES_DIR $Feature) "uninstall.ps1"
    Log-Info "Destroying: $Feature"

    if (-not (_Executor-RunScript -ScriptPath $script)) {
        Log-Error "executor: failed to uninstall feature: $Feature"
        return $false
    }
    return $true
}

function _Executor-Install {
    param([string]$Feature, [string]$ConfigVersion = "")

    $script = Join-Path (Join-Path $env:DOTFILES_FEATURES_DIR $Feature) "install.ps1"
    Log-Info "Installing: $Feature"

    $env = @{}
    if (-not [string]::IsNullOrWhiteSpace($ConfigVersion)) {
        $env["DOTFILES_FEATURE_CONFIG_VERSION"] = $ConfigVersion
    }

    if (-not (_Executor-RunScript -ScriptPath $script -EnvVars $env)) {
        Log-Error "executor: failed to install feature: $Feature"
        return $false
    }
    return $true
}

function _Executor-Replace {
    param([string]$Feature, [string]$ConfigVersion = "")

    Log-Info "Replacing: $Feature"

    $uninstallScript = Join-Path (Join-Path $env:DOTFILES_FEATURES_DIR $Feature) "uninstall.ps1"
    if (-not (_Executor-RunScript -ScriptPath $uninstallScript)) {
        Log-Error "executor: failed to uninstall before replace: $Feature"
        return $false
    }

    return (_Executor-Install -Feature $Feature -ConfigVersion $ConfigVersion)
}

# ── Plan reporting ────────────────────────────────────────────────────────────

function _Executor-ReportBlocked {
    param([object]$Plan)

    $blocked = @($Plan.blocked)
    if ($blocked.Count -gt 0) {
        Log-Warn "Skipping $($blocked.Count) blocked feature(s):"
        foreach ($b in $blocked) {
            Log-Warn "  ⊘ $($b.feature): $($b.reason)"
        }
    }
}

function _Executor-ReportSummary {
    param([object]$Plan)

    $s = $Plan.summary
    Log-Info "Plan: create=$($s.create)  destroy=$($s.destroy)  replace=$($s.replace)  noop=$($s.noop)  blocked=$($s.blocked)"
}

# ── Public API ────────────────────────────────────────────────────────────────

function Invoke-ExecutorRun {
    <#
    .SYNOPSIS Execute all actions in the given plan JSON string.
    Blocked features are skipped.
    Any action failure causes immediate abort (exit 1).
    #>
    param(
        [Parameter(Mandatory=$true)] [string]$PlanJson
    )

    if ([string]::IsNullOrWhiteSpace($PlanJson)) {
        Log-Error "Invoke-ExecutorRun: PlanJson is required"
        exit 1
    }

    $plan = $PlanJson | ConvertFrom-Json

    _Executor-ReportBlocked -Plan $plan
    _Executor-ReportSummary -Plan $plan

    $actions = @($plan.actions)

    if ($actions.Count -eq 0) {
        Log-Info "Nothing to do."
        return
    }

    Log-Task "Executing plan ($($actions.Count) actions)..."

    foreach ($action in $actions) {
        $feature       = $action.feature
        $operation     = $action.operation
        $configVersion = ""
        if ($action.details -and $action.details.PSObject.Properties['config_version'] -and
            $null -ne $action.details.config_version) {
            $configVersion = [string]$action.details.config_version
        }

        $ok = switch ($operation) {
            "destroy"          { _Executor-Destroy  -Feature $feature }
            "create"           { _Executor-Install  -Feature $feature -ConfigVersion $configVersion }
            "replace"          { _Executor-Replace  -Feature $feature -ConfigVersion $configVersion }
            "replace_backend"  { _Executor-Replace  -Feature $feature -ConfigVersion $configVersion }
            default {
                Log-Error "executor: unknown operation '$operation' for feature '$feature'"
                $false
            }
        }

        if (-not $ok) {
            Log-Error "executor: aborting due to failure on feature: $feature"
            exit 1
        }
    }
}
