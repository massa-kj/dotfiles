#!/usr/bin/env bash
set -euo pipefail

ROOT="/dotfiles"
PROFILE_V20="/tmp/profile_v20.yaml"
PROFILE_V22="/tmp/profile_v22.yaml"
STATE_FILE="$ROOT/state/installed.json"

echo "==> Version upgrade scenario"

cd "$ROOT"

echo "==> Running bootstrap"
./platforms/linux/bootstrap.sh

echo "==> Creating profile with Node 20"
cat > "$PROFILE_V20" <<EOF
features:
  bash: {}
  brew: {}
  git: {}
  mise: {}
  node:
    version: "20"
EOF

echo "==> First apply (Node 20)"
./dotfiles apply "$PROFILE_V20"

# Activate brew and mise for tests
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
eval "$(mise activate bash)"

echo "==> Verifying Node 20 installed"
NODE_VERSION_1=$(jq -r '.features.node.runtime.version' "$STATE_FILE")
if [[ "$NODE_VERSION_1" != "20" ]]; then
  echo "Node version not recorded correctly: $NODE_VERSION_1"
  exit 1
fi

echo "==> Verifying node 20 package in state"
NODE_PACKAGE=$(jq -r '.features.node.packages[] | select(startswith("node@"))' "$STATE_FILE")
if [[ ! "$NODE_PACKAGE" =~ ^node@20 ]]; then
  echo "Node 20 package not registered: $NODE_PACKAGE"
  exit 1
fi

echo ""
echo "==> Creating profile with Node 22 (version change)"
cat > "$PROFILE_V22" <<EOF
features:
  bash: {}
  brew: {}
  git: {}
  mise: {}
  node:
    version: "22"
EOF

echo "==> Second apply (Node 22 - should trigger reinstall)"
./dotfiles apply "$PROFILE_V22"

echo "==> Verifying Node 22 installed"
NODE_VERSION_2=$(jq -r '.features.node.runtime.version' "$STATE_FILE")
if [[ "$NODE_VERSION_2" != "22" ]]; then
  echo "Node version not updated correctly: $NODE_VERSION_2"
  exit 1
fi

echo "==> Verifying node 22 package in state"
NODE_PACKAGE=$(jq -r '.features.node.packages[] | select(startswith("node@"))' "$STATE_FILE")
if [[ ! "$NODE_PACKAGE" =~ ^node@22 ]]; then
  echo "Node 22 package not registered: $NODE_PACKAGE"
  exit 1
fi

echo "==> Verifying version changed from 20 to 22"
if [[ "$NODE_VERSION_1" == "$NODE_VERSION_2" ]]; then
  echo "Version did not change"
  exit 1
fi

echo ""
echo "==> Version upgrade scenario PASSED"
