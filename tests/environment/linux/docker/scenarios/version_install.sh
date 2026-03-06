#!/usr/bin/env bash
set -euo pipefail

ROOT="/dotfiles"
PROFILE_VERSION="$ROOT/tests/environment/linux/docker/fixtures/profile-version-v20.yaml"
STATE_FILE="$ROOT/state/state.json"

echo "==> Version install scenario"

cd "$ROOT"

# Use test-specific policy (no backup, standard backends)
export DOTFILES_POLICY_FILE="$ROOT/tests/environment/linux/docker/fixtures/policy.yaml"

echo "==> Running apply with version-specified features"
./dotfiles apply "$PROFILE_VERSION"

# Activate brew and mise for tests
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
eval "$(mise activate bash)"

echo "==> Checking state file existence"
test -f "$STATE_FILE"

echo "==> Validating JSON format"
jq empty "$STATE_FILE" > /dev/null

echo "==> Verifying node is installed"
if ! jq -e '.features.node' "$STATE_FILE" > /dev/null; then
  echo "node feature not found in state"
  exit 1
fi

echo "==> Verifying node version recorded in state"
NODE_VERSION=$(jq -r '.features.node.runtime.version' "$STATE_FILE")
if [[ "$NODE_VERSION" != "20" ]]; then
  echo "Node version not recorded correctly: $NODE_VERSION"
  exit 1
fi

echo "==> Verifying node package registered in state"
NODE_PACKAGE=$(jq -r '.features.node.packages[] | select(startswith("node@"))' "$STATE_FILE")
echo "  Registered package: $NODE_PACKAGE"
if [[ ! "$NODE_PACKAGE" =~ ^node@20 ]]; then
  echo "Node package not registered correctly: $NODE_PACKAGE"
  exit 1
fi

echo "==> Checking mise is available"
if ! command -v mise >/dev/null 2>&1; then
  echo "mise command not found"
  exit 1
fi

echo ""
echo "==> Version install scenario PASSED"
