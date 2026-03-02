#!/usr/bin/env bash
# cmd/apply.sh — CLI entry point for the apply command.
#
# This script is intentionally thin: argument parsing, platform guard,
# library sourcing, then a single call to orchestrator_apply().
# All pipeline logic lives in core/lib/orchestrator.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export DOTFILES_ROOT

# ── Library loading ───────────────────────────────────────────────────────────

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/package.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"
source "$DOTFILES_ROOT/core/lib/resolver.sh"
source "$DOTFILES_ROOT/core/lib/orchestrator.sh"

# ── Platform guard ────────────────────────────────────────────────────────────

case "$DOTFILES_PLATFORM" in
    linux|wsl) ;;
    windows)
        log_error "On Windows, use dotfiles.ps1 instead."
        exit 1
        ;;
    *)
        log_error "Unknown platform: $DOTFILES_PLATFORM"
        exit 1
        ;;
esac

# ── Usage ─────────────────────────────────────────────────────────────────────

_usage() {
    cat <<EOF
Usage: dotfiles apply <profile.yaml>

Apply a dotfiles profile to the system.

Arguments:
  profile.yaml    Path to the profile file

Examples:
  dotfiles apply profiles/linux.yaml
  dotfiles apply profiles/wsl.yaml
EOF
    exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
    _usage
fi

PROFILE_FILE="$1"

log_task "Applying profile: $PROFILE_FILE"

# ── Delegate to orchestrator ──────────────────────────────────────────────────

orchestrator_apply "$PROFILE_FILE"
