#!/usr/bin/env bash
set -euo pipefail

ROOT="/dotfiles"
PROFILE="$ROOT/tests/environment/linux/docker/fixtures/profile-base.yaml"
export XDG_CONFIG_HOME="/tmp/dotfiles-xdg-config"
export XDG_STATE_HOME="/tmp/dotfiles-xdg-state"
STATE_FILE="$XDG_STATE_HOME/dotfiles/state.json"

echo "==> Idempotent scenario"

cd "$ROOT"

# Use test-specific policy that does not require a package-manager feature.
export DOTFILES_POLICY_FILE="$ROOT/tests/environment/linux/docker/fixtures/policy-apt.yaml"

rm -rf /root/.bashrc /root/.bashrc.d

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

echo "==> Verifying no duplicate resource id entries per feature"
jq -e '
  .features[]?
  | (.resources // []) as $r
  | (($r | map(.id) | length) == ($r | map(.id) | unique | length))
' "$STATE_FILE" > /dev/null

echo "==> Verifying no duplicate fs.path entries across features"
jq -e '
  ([.features[]?.resources[]? | select(.kind == "fs") | .fs.path] | length)
  ==
  ([.features[]?.resources[]? | select(.kind == "fs") | .fs.path] | unique | length)
' "$STATE_FILE" > /dev/null

echo "==> Idempotent scenario PASSED"
