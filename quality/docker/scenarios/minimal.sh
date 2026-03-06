#!/usr/bin/env bash
set -euo pipefail

ROOT="/dotfiles"
PROFILE="profiles/linux.yaml"
STATE_FILE="$ROOT/state/state.json"

echo "==> Minimal scenario"

cd "$ROOT"

echo "==> Running bootstrap"
./platforms/linux/bootstrap.sh

echo "==> Running apply"
./dotfiles apply "$PROFILE"

echo "==> Checking state file existence"
test -f "$STATE_FILE"

echo "==> Validating JSON format"
jq empty "$STATE_FILE" > /dev/null

echo "==> Checking version field"
VERSION=$(jq -r '.version' "$STATE_FILE")
if [[ "$VERSION" != "1" ]]; then
  echo "Invalid state version: $VERSION"
  exit 1
fi

echo "==> Checking features object exists"
jq -e '.features' "$STATE_FILE" > /dev/null

echo "==> Checking no duplicate features"
DUP_COUNT=$(jq -r '.features | keys | length as $l | unique | length != $l' "$STATE_FILE")
if [[ "$DUP_COUNT" == "true" ]]; then
  echo "Duplicate features detected"
  exit 1
fi

echo "==> Checking absolute paths in files"
# Check that all file paths start with /
jq -e '.features | to_entries[] | .value.files[]? | select(startswith("/") | not) | "Non-absolute path: \(.)"' "$STATE_FILE" > /dev/null && {
  echo "Non-absolute paths detected"
  exit 1
} || true

echo "==> Minimal scenario PASSED"
