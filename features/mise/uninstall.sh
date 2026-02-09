#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/fs.sh"

FEATURE_NAME="mise"

log_task "Uninstalling feature: $FEATURE_NAME"

# Check if feature is installed
if ! state_has_feature "$FEATURE_NAME"; then
    log_warn "Feature $FEATURE_NAME is not installed"
    exit 0
fi

# Remove configuration files tracked in state
remove_tracked_files "$FEATURE_NAME"

# Note: We do NOT uninstall mise package
log_info "Note: mise package is not removed (may be used by other tools)"

# Remove feature from state
state_remove_feature "$FEATURE_NAME"

log_success "Feature $FEATURE_NAME uninstalled successfully"
