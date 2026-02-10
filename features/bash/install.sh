#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/fs.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="bash"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Check if bash is available (should be installed by default)
if ! has_command "bash"; then
    log_error "bash is not available"
    exit 1
fi

# Deploy configuration files
FEATURE_FILES_DIR="$SCRIPT_DIR/files"
TARGET_HOME="${HOME}"

if [[ -d "$FEATURE_FILES_DIR" ]]; then
    log_info "Deploying bash configuration files..."
    
    # Deploy .bashrc if exists
    if [[ -f "$FEATURE_FILES_DIR/.bashrc" ]]; then
        link_file "$FEATURE_NAME" "$FEATURE_FILES_DIR/.bashrc" "$TARGET_HOME/.bashrc"
    fi
    
    # Deploy .bashrc.d if exists
    if [[ -d "$FEATURE_FILES_DIR/.bashrc.d" ]]; then
        link_dir "$FEATURE_NAME" "$FEATURE_FILES_DIR/.bashrc.d" "$TARGET_HOME/.bashrc.d"
    fi
fi

log_success "Feature $FEATURE_NAME installed successfully"
log_info "Run 'source ~/.bashrc' to apply changes"
