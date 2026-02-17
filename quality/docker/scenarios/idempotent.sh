#!/usr/bin/env bash
set -euo pipefail

ROOT="/dotfiles"
PROFILE="profiles/linux.yaml"
STATE_FILE="$ROOT/state/installed.json"

echo "==> Idempotent scenario"

cd "$ROOT"

echo "==> Running bootstrap"
./platforms/linux/bootstrap.sh

echo "==> First apply"
./dotfiles apply "$PROFILE"

echo "==> Snapshotting state"
cp "$STATE_FILE" /tmp/state_before.json

echo "==> Second apply"
./dotfiles apply "$PROFILE"

echo "==> Comparing state"
if ! diff -u /tmp/state_before.json "$STATE_FILE"; then
  echo "State changed after second apply"
  exit 1
fi

echo "==> Verifying no duplicate package entries"
jq -e '
  .features[]? 
  | (.packages // []) as $p
  | ($p | length) == ($p | unique | length)
' "$STATE_FILE" > /dev/null

echo "==> Verifying no duplicate file entries"
jq -e '
  .features[]? 
  | (.files // []) as $f
  | ($f | length) == ($f | unique | length)
' "$STATE_FILE" > /dev/null

echo "==> Idempotent scenario PASSED"
