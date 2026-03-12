#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Unit tests: spec_version validation (_validate_spec_versions)
#
# Verifies that features with unsupported spec_version are pre-blocked,
# and valid features pass through unchanged.
# Run directly: bash tests/unit/test_spec_version.sh
# Exit code 0 = all pass, 1 = one or more failures.
# -----------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

export DOTFILES_ROOT="$TMPDIR_ROOT/repo"
export DOTFILES_PLATFORM="linux"
export DOTFILES_CONFIG_HOME="$TMPDIR_ROOT/config/dotfiles"
export DOTFILES_DATA_HOME="$TMPDIR_ROOT/data/dotfiles"
export DOTFILES_SOURCES_FILE="$DOTFILES_CONFIG_HOME/sources.yaml"
export SUPPORTED_FEATURE_SPEC_VERSION=1

mkdir -p "$DOTFILES_ROOT/features" "$DOTFILES_ROOT/backends"
mkdir -p "$DOTFILES_CONFIG_HOME/features"
mkdir -p "$DOTFILES_DATA_HOME/sources"

# Source only the modules required by _validate_spec_versions
source "$REPO_ROOT/core/lib/env.sh"
source "$REPO_ROOT/core/lib/logger.sh"
source "$REPO_ROOT/core/lib/source_registry.sh"

# Minimal stub for modules orchestrator.sh lazily sources (not needed here)
# orchestrator.sh lazily sources resolver, backend_registry, planner, executor.
# Override lazy-load guards so they are not triggered.
read_feature_metadata() { true; }
backend_registry_load_policy() { true; }
planner_run() { true; }
executor_run() { true; }
state_init() { true; }
state_has_feature() { false; }
state_list_features() { true; }
read_profile() { true; }
resolve_dependencies() { true; }

source "$REPO_ROOT/core/lib/orchestrator.sh"

# ── Feature setup ─────────────────────────────────────────────────────────────

FEATURES_DIR="$DOTFILES_ROOT/features"

# good: spec_version 1 (supported)
mkdir -p "$FEATURES_DIR/good"
cat > "$FEATURES_DIR/good/feature.yaml" <<'EOF'
spec_version: 1
mode: script
description: good feature
depends: []
EOF

# future: spec_version 999 (unsupported)
mkdir -p "$FEATURES_DIR/future"
cat > "$FEATURES_DIR/future/feature.yaml" <<'EOF'
spec_version: 999
mode: script
description: future feature with unknown spec_version
depends: []
EOF

# no_version: spec_version not set (defaults to 1 — supported)
mkdir -p "$FEATURES_DIR/no_version"
cat > "$FEATURES_DIR/no_version/feature.yaml" <<'EOF'
mode: script
description: feature without explicit spec_version
depends: []
EOF

# ── Tests ─────────────────────────────────────────────────────────────────────

echo "_validate_spec_versions: supported spec_version passes through"
declare -a vsv_features=("core/good")
declare -a vsv_valid=()
vsv_blocked=""
_validate_spec_versions vsv_features vsv_valid vsv_blocked 2>/dev/null

_assert_eq \
    "good feature is in valid list" \
    "core/good" \
    "${vsv_valid[0]:-}"

_assert_eq \
    "blocked list is empty for supported feature" \
    "[]" \
    "$vsv_blocked"

# ── Test: unsupported spec_version is blocked ──────────────────────────────

echo "_validate_spec_versions: unsupported spec_version is blocked"
declare -a vsv2_features=("core/future")
declare -a vsv2_valid=()
vsv2_blocked=""
_validate_spec_versions vsv2_features vsv2_valid vsv2_blocked 2>/dev/null

_assert_eq \
    "future feature is NOT in valid list" \
    "0" \
    "${#vsv2_valid[@]}"

blocked_count=$(echo "$vsv2_blocked" | jq 'length')
_assert_eq \
    "blocked list has 1 entry for unsupported spec_version" \
    "1" \
    "$blocked_count"

blocked_feature=$(echo "$vsv2_blocked" | jq -r '.[0].feature')
_assert_eq \
    "blocked entry has correct feature id" \
    "core/future" \
    "$blocked_feature"

blocked_reason=$(echo "$vsv2_blocked" | jq -r '.[0].reason')
if [[ "$blocked_reason" == *"unsupported spec_version: 999"* ]]; then
    echo "  PASS  blocked reason mentions spec_version: 999"
    (( _PASS++ )) || true
else
    echo "  FAIL  blocked reason should mention spec_version: 999, got: $blocked_reason"
    (( _FAIL++ )) || true
fi

# ── Test: missing spec_version defaults to 1 (supported) ──────────────────

echo "_validate_spec_versions: missing spec_version defaults to 1"
declare -a vsv3_features=("core/no_version")
declare -a vsv3_valid=()
vsv3_blocked=""
_validate_spec_versions vsv3_features vsv3_valid vsv3_blocked 2>/dev/null

_assert_eq \
    "no_version feature is in valid list (defaults to 1)" \
    "core/no_version" \
    "${vsv3_valid[0]:-}"

_assert_eq \
    "blocked list is empty when spec_version defaults to 1" \
    "[]" \
    "$vsv3_blocked"

# ── Test: mixed valid and blocked split correctly ──────────────────────────

echo "_validate_spec_versions: mixed valid and blocked features"
declare -a vsv4_features=("core/good" "core/future" "core/no_version")
declare -a vsv4_valid=()
vsv4_blocked=""
_validate_spec_versions vsv4_features vsv4_valid vsv4_blocked 2>/dev/null

_assert_eq \
    "valid list has 2 entries (good + no_version)" \
    "2" \
    "${#vsv4_valid[@]}"

mixed_blocked_count=$(echo "$vsv4_blocked" | jq 'length')
_assert_eq \
    "blocked list has 1 entry (future)" \
    "1" \
    "$mixed_blocked_count"

# ── Test: _plan_inject_blocked merges into plan JSON ──────────────────────

echo "_plan_inject_blocked: injects blocked entries into plan JSON"

base_plan='{"actions":[],"noops":[],"blocked":[],"summary":{"create":0,"destroy":0,"replace":0,"replace_backend":0,"strengthen":0,"noop":0,"blocked":0}}'
extra='[{"feature":"core/future","reason":"unsupported spec_version: 999 (max: 1)"}]'

injected=$(_plan_inject_blocked "$base_plan" "$extra")

injected_count=$(echo "$injected" | jq '.blocked | length')
_assert_eq \
    "injected plan has 1 blocked entry" \
    "1" \
    "$injected_count"

injected_summary=$(echo "$injected" | jq '.summary.blocked')
_assert_eq \
    "injected plan summary.blocked is updated to 1" \
    "1" \
    "$injected_summary"

# ── Test: _plan_inject_blocked is no-op for empty extra ────────────────────

echo "_plan_inject_blocked: empty extra is a no-op"

noop_result=$(_plan_inject_blocked "$base_plan" "[]")
_assert_eq \
    "no-op result equals base plan" \
    "$base_plan" \
    "$noop_result"

# ── Summary ────────────────────────────────────────────────────────────────────

_print_summary
