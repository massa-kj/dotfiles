#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"

FEATURE_NAME="brew"

log_task "Uninstalling feature: $FEATURE_NAME"

# Check if feature is installed
if ! state_has_feature "$FEATURE_NAME"; then
    log_warn "Feature $FEATURE_NAME is not installed"
    exit 0
fi

# Note: We do NOT uninstall Homebrew itself as it may have many packages
log_warn "Homebrew itself is not uninstalled (many packages may depend on it)"
log_info "To manually uninstall Homebrew, run:"
log_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""

# Remove feature from state
state_remove_feature "$FEATURE_NAME"

log_success "Feature $FEATURE_NAME uninstalled successfully"
