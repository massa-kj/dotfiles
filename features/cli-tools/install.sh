#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"

FEATURE_NAME="cli-tools"

log_task "Installing feature: $FEATURE_NAME"

# All packages (fd, fzf, ghq, ripgrep, unzip) are installed by executor
# (declared in feature.linux.yaml packages section).

log_success "Feature $FEATURE_NAME installed successfully"
