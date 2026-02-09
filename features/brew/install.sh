#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="brew"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Check platform
case "$DOTFILES_PLATFORM" in
    linux|wsl)
        ;;
    *)
        log_error "Homebrew on Linux is only supported on Linux/WSL"
        exit 1
        ;;
esac

# Check if brew is already installed
if has_command "brew"; then
    log_info "Homebrew is already installed"
    BREW_PREFIX=$(brew --prefix)
    log_info "Homebrew prefix: $BREW_PREFIX"
    state_add_package "$FEATURE_NAME" "homebrew"
else
    log_info "Installing Homebrew..."
    
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Setup brew environment
    BREW_PREFIX="/home/linuxbrew/.linuxbrew"
    if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
        eval "$($BREW_PREFIX/bin/brew shellenv)"
        
        # Add to shell profile if not already present
        PROFILE_FILE="$HOME/.profile"
        SHELLENV_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
        
        if [[ -f "$PROFILE_FILE" ]] && ! grep -qF "$SHELLENV_LINE" "$PROFILE_FILE"; then
            log_info "Adding brew shellenv to $PROFILE_FILE"
            echo '' >> "$PROFILE_FILE"
            echo '# Homebrew' >> "$PROFILE_FILE"
            echo "$SHELLENV_LINE" >> "$PROFILE_FILE"
        fi
        
        state_add_package "$FEATURE_NAME" "homebrew"
        log_success "Homebrew installed successfully"
    else
        log_error "Homebrew installation failed"
        exit 1
    fi
fi

log_success "Feature $FEATURE_NAME installed successfully"
log_info "Reload your shell or run: eval \"\$(brew shellenv)\""
