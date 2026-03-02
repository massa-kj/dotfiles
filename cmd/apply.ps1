# cmd/apply.ps1 — CLI entry point for the apply command.
#
# This script is intentionally thin: argument parsing, platform guard,
# library loading, then a single call to Invoke-OrchestratorApply.
# All pipeline logic lives in core/lib/orchestrator.ps1.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ProfileFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Library loading ───────────────────────────────────────────────────────────

$ScriptRoot = $PSScriptRoot
$global:DOTFILES_ROOT = (Get-Item "$ScriptRoot\..").FullName

. "$global:DOTFILES_ROOT\core\lib\env.ps1"
. "$global:DOTFILES_ROOT\core\lib\logger.ps1"
. "$global:DOTFILES_ROOT\core\lib\state.ps1"
. "$global:DOTFILES_ROOT\core\lib\package.ps1"
. "$global:DOTFILES_ROOT\core\lib\runner.ps1"
. "$global:DOTFILES_ROOT\core\lib\resolver.ps1"
. "$global:DOTFILES_ROOT\core\lib\orchestrator.ps1"

# ── Platform guard ────────────────────────────────────────────────────────────

if ($global:DOTFILES_PLATFORM -ne "windows") {
    Log-Error "This script is for Windows only. On Linux/WSL, run dotfiles instead."
    exit 1
}

# ── Usage ─────────────────────────────────────────────────────────────────────

function _Show-ApplyUsage {
    Write-Host @"
Usage: dotfiles.ps1 apply <profile.yaml>

Apply a dotfiles profile to the system.

Arguments:
  profile.yaml    Path to the profile file

Examples:
  dotfiles.ps1 apply profiles\windows.yaml
"@
    exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────

if ([string]::IsNullOrWhiteSpace($ProfileFile)) {
    _Show-ApplyUsage
}

Log-Task "Applying profile: $ProfileFile"

# ── Delegate to orchestrator ──────────────────────────────────────────────────

Invoke-OrchestratorApply -ProfileFile $ProfileFile
