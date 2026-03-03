#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"

FEATURE_NAME="tmux"

log_task "Installing feature: $FEATURE_NAME"

# tmux package and config file (.tmux.conf) are managed by executor
# (declared in meta.linux.yaml packages and files sections).

log_success "Feature $FEATURE_NAME installed successfully"
