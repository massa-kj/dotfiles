#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"

FEATURE_NAME="git-tools"

log_task "Uninstalling feature: $FEATURE_NAME"

# Check if feature is installed
if ! state_has_feature "$FEATURE_NAME"; then
    log_warn "Feature $FEATURE_NAME is not installed"
    exit 0
fi

# Note: We do NOT uninstall packages as they may be used by other tools
log_info "Note: Git tools packages are not removed (may be used elsewhere)"

# Remove feature from state
state_remove_feature "$FEATURE_NAME"

log_success "Feature $FEATURE_NAME uninstalled successfully"
