#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The nvim directory (where the config file is located)
NVIM_DIR="${SCRIPT_DIR}/../features/neovim/files/nvim"

echo "==> Changing to $NVIM_DIR"
cd "$NVIM_DIR"

echo "==> Running stylua..."
stylua -c ./lua

echo "==> Running luacheck..."
luacheck .
