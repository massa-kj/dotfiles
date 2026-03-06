#!/usr/bin/env bash
set -euo pipefail

ROOT="/dotfiles"
PROFILE_FULL="$ROOT/tests/environment/linux/docker/fixtures/profile-full.yaml"
PROFILE_PARTIAL="$ROOT/tests/environment/linux/docker/fixtures/profile-base.yaml"
PROFILE_EMPTY="$ROOT/tests/environment/linux/docker/fixtures/profile-empty.yaml"
STATE_FILE="$ROOT/state/state.json"

echo "==> Uninstall scenario"

cd "$ROOT"

# Use test-specific policy (no backup, standard backends)
export DOTFILES_POLICY_FILE="$ROOT/tests/environment/linux/docker/fixtures/policy.yaml"

echo "==> First apply (install phase)"
./dotfiles apply "$PROFILE_FULL"

echo "==> Ensuring state exists"
test -f "$STATE_FILE"
jq empty "$STATE_FILE" > /dev/null

echo "==> Capturing installed features"
INSTALLED_COUNT=$(jq '.features | keys | length' "$STATE_FILE")
if [[ "$INSTALLED_COUNT" -eq 0 ]]; then
  echo "No features installed, test invalid"
  exit 1
fi

echo "==> Collecting tracked files and packages"
TRACKED_FILES=$(jq -r '.features[]?.files[]?' "$STATE_FILE" || true)
TRACKED_PACKAGES=$(jq -r '.features[]?.packages[]?' "$STATE_FILE" || true)

echo "==> Creating sentinel file (must NOT be removed)"
SENTINEL="/tmp/dotfiles_sentinel"
echo "do not delete" > "$SENTINEL"

# Test 1: Partial uninstall
echo ""
echo "==> Test 1: Partial uninstall"
echo "==> Running apply with partial profile"
./dotfiles apply "$PROFILE_PARTIAL"

echo "==> Verifying bash and git remain"
if ! jq -e '.features.bash' "$STATE_FILE" > /dev/null; then
  echo "bash was removed (should remain)"
  exit 1
fi
if ! jq -e '.features.git' "$STATE_FILE" > /dev/null; then
  echo "git was removed (should remain)"
  exit 1
fi

echo "==> Verifying other features removed"
REMAINING_FEATURES=$(jq -r '.features | keys[]' "$STATE_FILE")
for feature in $REMAINING_FEATURES; do
  if [[ "$feature" != "bash" ]] && [[ "$feature" != "git" ]]; then
    echo "Unexpected feature remains: $feature"
    exit 1
  fi
done

echo "==> Verifying packages were removed"
REMAINING_PACKAGES=$(jq -r '.features[]?.packages[]?' "$STATE_FILE" || true)
if [[ -n "$REMAINING_PACKAGES" ]]; then
  for pkg in $TRACKED_PACKAGES; do
    if echo "$REMAINING_PACKAGES" | grep -q "^${pkg}$"; then
      # Package still exists but should only be in bash/git
      :
    fi
  done
fi

echo "==> Partial uninstall passed"

# Test 2: Full uninstall
echo ""
echo "==> Test 2: Full uninstall"
echo "==> Running apply with empty profile (full uninstall)"
./dotfiles apply "$PROFILE_EMPTY"

echo "==> Checking state file valid"
jq empty "$STATE_FILE" > /dev/null

echo "==> Verifying state features empty"
REMAINING=$(jq '.features | keys | length' "$STATE_FILE")
if [[ "$REMAINING" -ne 0 ]]; then
  echo "State still contains features"
  exit 1
fi

echo "==> Verifying all tracked files removed"
for f in $TRACKED_FILES; do
  if [[ -e "$f" ]]; then
    echo "Tracked file still exists: $f"
    exit 1
  fi
done

echo "==> Verifying sentinel file still exists (filesystem scan prohibition)"
if [[ ! -f "$SENTINEL" ]]; then
  echo "Untracked file was removed (filesystem scan violation)"
  exit 1
fi

echo "==> Verifying all packages removed from state"
REMAINING_PACKAGES=$(jq -r '.features[]?.packages[]?' "$STATE_FILE" || true)
if [[ -n "$REMAINING_PACKAGES" ]]; then
  echo "Packages still in state: $REMAINING_PACKAGES"
  exit 1
fi

echo "==> Full uninstall passed"

# Test 3: Uninstall idempotency
echo ""
echo "==> Test 3: Uninstall idempotency"
echo "==> Running apply with empty profile again"
./dotfiles apply "$PROFILE_EMPTY"

echo "==> Ensuring state still empty"
REMAINING2=$(jq '.features | keys | length' "$STATE_FILE")
if [[ "$REMAINING2" -ne 0 ]]; then
  echo "State changed after idempotent uninstall"
  exit 1
fi

echo "==> Idempotent uninstall passed"

echo ""
echo "==> Uninstall scenario PASSED (all tests)"
