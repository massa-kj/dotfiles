#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="bash"

log_task "Installing feature: $FEATURE_NAME"

# Verify bash is available (should always be present on the system)
if ! has_command "bash"; then
    log_error "bash is not available"
    exit 1
fi

# Configuration files (.bashrc, .bashrc.d) are deployed by executor
# (declared in feature.yaml files section).

log_success "Feature $FEATURE_NAME installed successfully"
log_info "Run 'source ~/.bashrc' to apply changes"
