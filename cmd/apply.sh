#!/usr/bin/env bash
# cmd/apply.sh
# Apply command implementation

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/resolver.sh"
source "$DOTFILES_ROOT/core/lib/orchestrator.sh"

# Platform check
case "$DOTFILES_PLATFORM" in
  linux|wsl) ;;
  windows)
    log_error "On Windows, run dotfiles.ps1 instead."
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
Usage: dotfiles apply <profile.yaml>

Apply a dotfiles profile to the system.

Arguments:
  profile.yaml    Path to the profile file

Examples:
  dotfiles apply profiles/minimal.yaml
  dotfiles apply profiles/dev.yaml
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
FEATURES_TO_REINSTALL=()
calculate_diff SORTED_FEATURES FEATURES_TO_INSTALL FEATURES_TO_UNINSTALL FEATURES_TO_REINSTALL

# Execute in order:
# 1. Uninstall removed features
# 2. Uninstall features to reinstall (for version change)
# 3. Install new features
# 4. Install reinstalled features (with new version)

# Uninstall removed features
run_uninstall FEATURES_TO_UNINSTALL || exit 1

# Uninstall features that need reinstall (version mismatch)
if [[ ${#FEATURES_TO_REINSTALL[@]} -gt 0 ]]; then
    log_task "Preparing features for reinstall..."
    run_uninstall FEATURES_TO_REINSTALL || exit 1
fi

# Install new features
run_install FEATURES_TO_INSTALL || exit 1

# Reinstall features with new version
if [[ ${#FEATURES_TO_REINSTALL[@]} -gt 0 ]]; then
    log_task "Reinstalling features with version updates..."
    run_install FEATURES_TO_REINSTALL || exit 1
fi

# Print summary
print_summary
