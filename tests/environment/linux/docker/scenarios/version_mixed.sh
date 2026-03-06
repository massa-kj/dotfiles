#!/usr/bin/env bash
set -euo pipefail

ROOT="/dotfiles"
PROFILE_MIXED="$ROOT/tests/environment/linux/docker/fixtures/profile-version-mixed.yaml"
STATE_FILE="$ROOT/state/state.json"

echo "==> Version mixed scenario"

cd "$ROOT"

# Use test-specific policy (no backup, standard backends)
export DOTFILES_POLICY_FILE="$ROOT/tests/environment/linux/docker/fixtures/policy.yaml"

echo "==> Running apply with mixed features"
./dotfiles apply "$PROFILE_MIXED"

echo "==> Checking state file existence"
test -f "$STATE_FILE"

echo "==> Validating JSON format"
jq empty "$STATE_FILE" > /dev/null

echo "==> Verifying node has version in state"
NODE_VERSION=$(jq -r '.features.node.runtime.version' "$STATE_FILE")
if [[ "$NODE_VERSION" != "20" ]]; then
  echo "Node version not recorded: $NODE_VERSION"
  exit 1
fi

echo "==> Verifying git has no version in state"
GIT_VERSION=$(jq -r '.features.git.runtime.version // "none"' "$STATE_FILE")
if [[ "$GIT_VERSION" != "none" ]]; then
  echo "Git should not have version recorded: $GIT_VERSION"
  exit 1
fi

echo "==> Verifying bash has no version in state"
BASH_VERSION=$(jq -r '.features.bash.runtime.version // "none"' "$STATE_FILE")
if [[ "$BASH_VERSION" != "none" ]]; then
  echo "Bash should not have version recorded: $BASH_VERSION"
  exit 1
fi

echo "==> Verifying all features installed"
FEATURE_COUNT=$(jq '.features | keys | length' "$STATE_FILE")
if [[ "$FEATURE_COUNT" -lt 5 ]]; then
  echo "Not all features installed: $FEATURE_COUNT"
  exit 1
fi

echo ""
echo "==> Version mixed scenario PASSED"
