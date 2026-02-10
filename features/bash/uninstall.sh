#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/fs.sh"

FEATURE_NAME="bash"

log_task "Uninstalling feature: $FEATURE_NAME"

# Check if feature is installed
if ! state_has_feature "$FEATURE_NAME"; then
    log_warn "Feature $FEATURE_NAME is not installed"
    exit 0
fi

# Remove configuration files tracked in state
remove_tracked_files "$FEATURE_NAME"

# Remove feature from state
state_remove_feature "$FEATURE_NAME"

log_success "Feature $FEATURE_NAME uninstalled successfully"
