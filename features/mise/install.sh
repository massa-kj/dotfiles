#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="mise"

log_task "Installing feature: $FEATURE_NAME"

# mise package installation is handled by executor (declared in meta.yaml packages).
# Config files are handled by executor (declared in meta.yaml files).

if has_command "mise"; then
    log_info "mise is available"
else
    log_warn "mise not found in PATH — may need shell reload after brew installs it"
fi

log_success "Feature $FEATURE_NAME installed successfully"
log_info "Reload your shell or run: eval \"\$(mise activate bash)\""
