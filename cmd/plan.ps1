# cmd/plan.ps1 — CLI entry point for the plan command (Windows).
#
# Runs the full planning pipeline (profile → diff → classify → decide)
# without executing any changes. State is never modified.
#
# Usage:
#   dotfiles.ps1 plan <profile.yaml> [--verbose]
#
# Output:
#   Actions that would be taken, colored by operation type.
#   noop entries are hidden unless --verbose is specified.
#
# Exit codes:
#   0  — plan printed (may be all-noop)
#   1  — error (profile not found, resolver failure, etc.)

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ProfileFile,

    [switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Library loading ───────────────────────────────────────────────────────────

$ScriptRoot = $PSScriptRoot
$global:DOTFILES_ROOT = (Get-Item "$ScriptRoot\..").FullName

. "$global:DOTFILES_ROOT\core\lib\env.ps1"
. "$global:DOTFILES_ROOT\core\lib\logger.ps1"
. "$global:DOTFILES_ROOT\core\lib\state.ps1"
. "$global:DOTFILES_ROOT\core\lib\runner.ps1"
. "$global:DOTFILES_ROOT\core\lib\resolver.ps1"
. "$global:DOTFILES_ROOT\core\lib\orchestrator.ps1"

# ── Platform guard ────────────────────────────────────────────────────────────

if ($global:DOTFILES_PLATFORM -ne "windows") {
    Log-Error "This script is for Windows only. On Linux/WSL, run dotfiles instead."
    exit 1
}

# ── Usage ─────────────────────────────────────────────────────────────────────

function _Show-PlanUsage {
    Write-Host @"
Usage: dotfiles.ps1 plan <profile.yaml> [-Verbose]

Show what 'apply' would do without making any changes.

Arguments:
  profile.yaml    Path to the profile file

Options:
  -Verbose        Also list noop (already up-to-date) features

Exit codes:
  0  Plan displayed successfully
  1  Error

Examples:
  dotfiles.ps1 plan profiles\windows.yaml
  dotfiles.ps1 plan profiles\windows.yaml -Verbose
"@
    exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────

if ([string]::IsNullOrWhiteSpace($ProfileFile)) {
    _Show-PlanUsage
}

# ── Plan formatter ────────────────────────────────────────────────────────────

# Format-Plan <PlanJson> <ProfileFile> <ShowNoop>
# Format and print plan JSON to the console.
function Format-Plan {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PlanJson,

        [Parameter(Mandatory=$true)]
        [string]$Profile,

        [bool]$ShowNoop = $false
    )

    $plan = $PlanJson | ConvertFrom-Json

    Write-Host ""
    Write-Host "Plan: $Profile" -ForegroundColor White
    Write-Host ""

    $hasOutput = $false

    # Print active operations in action order (destroy → replace → create)
    foreach ($action in $plan.actions) {
        switch ($action.operation) {
            "destroy" {
                Write-Host ("  {0,-9} {1}" -f "destroy", $action.feature) -ForegroundColor Red
                $hasOutput = $true
            }
            "replace" {
                $from = if ($action.details.from_version) { $action.details.from_version } else { "" }
                $to   = if ($action.details.to_version)   { $action.details.to_version   } else { "" }
                if ($from -and $to) {
                    Write-Host ("  {0,-9} {1,-20} {2} → {3}" -f "replace", $action.feature, $from, $to) `
                        -ForegroundColor Yellow
                } else {
                    Write-Host ("  {0,-9} {1}" -f "replace", $action.feature) -ForegroundColor Yellow
                }
                $hasOutput = $true
            }
            "create" {
                $ver = if ($action.details.config_version) { $action.details.config_version } else { "" }
                if ($ver) {
                    Write-Host ("  {0,-9} {1,-20} {2}" -f "create", $action.feature, $ver) `
                        -ForegroundColor Green
                } else {
                    Write-Host ("  {0,-9} {1}" -f "create", $action.feature) -ForegroundColor Green
                }
                $hasOutput = $true
            }
        }
    }

    # Print blocked entries
    foreach ($item in $plan.blocked) {
        $reason = if ($item.reason) { $item.reason } else { "" }
        Write-Host ("  {0,-9} {1,-20} {2}" -f "blocked", $item.feature, $reason) -ForegroundColor Red
        $hasOutput = $true
    }

    # Print noop entries when --verbose
    if ($ShowNoop) {
        foreach ($item in $plan.noops) {
            Write-Host ("  {0,-9} {1}" -f "noop", $item.feature) -ForegroundColor DarkGray
            $hasOutput = $true
        }
    }

    if ($hasOutput) { Write-Host "" }

    $s = $plan.summary
    Write-Host ("Summary: create={0}  destroy={1}  replace={2}  noop={3}  blocked={4}" -f `
        $s.create, $s.destroy, $s.replace, $s.noop, $s.blocked) -ForegroundColor White
    Write-Host ""

    $blockedCount = $s.blocked
    $activeCount  = $s.create + $s.destroy + $s.replace

    if ($blockedCount -gt 0) {
        Write-Host "$blockedCount blocked feature(s) — run 'apply' to see details." -ForegroundColor Red
        Write-Host ""
    } elseif ($activeCount -eq 0) {
        Write-Host "Nothing to do." -ForegroundColor DarkGray
        Write-Host ""
    } else {
        Write-Host "Run 'dotfiles.ps1 apply $Profile' to apply these changes." -ForegroundColor White
        Write-Host ""
    }
}

# ── Plan pipeline ─────────────────────────────────────────────────────────────

Log-Task "Planning profile: $ProfileFile"

# Load backend policy (non-fatal if policies dir is absent)
Backend-Registry-LoadPolicy

# Initialise (or migrate) state — read-only after this point
if (-not (State-Init)) {
    Log-Error "Failed to initialise state"
    exit 1
}

# Parse profile
$desiredFeatures = Read-Profile -ProfileFile $ProfileFile
if ($null -eq $desiredFeatures) { exit 1 }

# Filter features by supported spec_version
$_svResult = Invoke-ValidateSpecVersions -Features $desiredFeatures
if ($null -eq $_svResult) { exit 1 }

# Resolve feature metadata + topological sort (only valid features)
if (-not (Read-FeatureMetadata -Features $_svResult.Valid)) { exit 1 }

$sortedFeatures = Resolve-Dependencies -DesiredFeatures $_svResult.Valid
if ($null -eq $sortedFeatures) { exit 1 }

# Plan: pure computation — no state writes
$planJson = Invoke-PlannerRun -ProfileFile $ProfileFile -SortedFeatures $sortedFeatures
if (-not $planJson) {
    Log-Error "Planner failed to produce a plan"
    exit 1
}
$planJson = Invoke-PlanInjectBlocked -PlanJson $planJson -BlockedExtraJson $_svResult.BlockedJson

# Display
Format-Plan -PlanJson $planJson -Profile $ProfileFile -ShowNoop $Verbose.IsPresent
