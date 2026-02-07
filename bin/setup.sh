#!/bin/bash

set -euo pipefail

source modules/common.sh

# Define the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 <target>"
  echo ""
  echo "Available targets:"
  echo "  all       Set up all components"
  echo "  shell     Set up shell and terminal configurations"
  echo "  git       Set up Git configurations"
  echo "  brew      Install Homebrew packages"
  echo "  mise      Install tools via mise"
  echo "  nvim      Set up Neovim and related dependencies"
  echo ""
  echo "Example:"
  echo "  $0 all"
  exit 1
}

run_install() {
  local target="$1"
  case "$target" in
    all)
      "$SCRIPT_DIR/modules/shell.sh"
      . ~/.bashrc
      "$SCRIPT_DIR/modules/git.sh"
      "$SCRIPT_DIR/modules/brew.sh"
      "$SCRIPT_DIR/modules/mise.sh"
      "$SCRIPT_DIR/modules/nvim.sh"
      ;;
    shell)
      "$SCRIPT_DIR/modules/shell.sh"
      ;;
    git)
      "$SCRIPT_DIR/modules/git.sh"
      ;;
    brew)
      "$SCRIPT_DIR/modules/brew.sh"
      ;;
    mise)
      "$SCRIPT_DIR/modules/mise.sh"
      ;;
    nvim)
      "$SCRIPT_DIR/modules/shell.sh"
      . ~/.bashrc
      "$SCRIPT_DIR/modules/brew.sh"
      "$SCRIPT_DIR/modules/mise.sh"
      "$SCRIPT_DIR/modules/nvim.sh"
      ;;
    *)
      log_error "Unknown target: $target"
      usage
      ;;
  esac
}

main() {
  if [[ $# -ne 1 ]]; then
    log_error "Missing required target argument."
    usage
  fi

  run_install "$1"
}

main "$@"
