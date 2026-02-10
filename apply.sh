#!/usr/bin/env bash
# apply.sh
# Entry point for applying dotfiles profiles

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$SCRIPT_DIR"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/resolver.sh"
source "$DOTFILES_ROOT/core/lib/orchestrator.sh"

# Platform check
case "$DOTFILES_PLATFORM" in
  linux|wsl) ;;
  windows)
    log_error "On Windows, run apply.ps1 instead."
    exit 1
    ;;
  *)
    log_error "Unknown platform: $DOTFILES_PLATFORM"
    exit 1
    ;;
esac

# Usage
usage() {
    cat <<EOF
Usage: $0 <profile.yaml>

Apply a dotfiles profile to the system.

Arguments:
  profile.yaml    Path to the profile file

Examples:
  $0 profiles/minimal.yaml
  $0 profiles/dev.yaml
EOF
    exit 1
}

# Parse arguments
if [[ $# -lt 1 ]]; then
    usage
fi

PROFILE_FILE="$1"

log_task "Applying profile: $PROFILE_FILE"

# Initialize state
state_init

# Read profile
DESIRED_FEATURES=()
read_profile "$PROFILE_FILE" DESIRED_FEATURES || exit 1

# Read metadata and resolve dependencies
read_feature_metadata DESIRED_FEATURES || exit 1

SORTED_FEATURES=()
resolve_dependencies DESIRED_FEATURES SORTED_FEATURES || exit 1

# Calculate diff
FEATURES_TO_INSTALL=()
FEATURES_TO_UNINSTALL=()
calculate_diff SORTED_FEATURES FEATURES_TO_INSTALL FEATURES_TO_UNINSTALL

# Execute uninstall and install
run_uninstall FEATURES_TO_UNINSTALL || exit 1
run_install FEATURES_TO_INSTALL || exit 1

# Print summary
print_summary
