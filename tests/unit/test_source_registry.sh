#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Unit tests: source_registry
#
# Tests canonical_id_normalize, canonical_id_parse, canonical_id_validate.
# Run directly: bash tests/unit/test_source_registry.sh
# Exit code 0 = all pass, 1 = one or more failures.
# -----------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ── Minimal logger stub (no color, writes to stderr) ──────────────────────────
log_error() { echo "[ERROR] $*" >&2; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_info()  { echo "[INFO]  $*" >&2; }

source "$REPO_ROOT/core/lib/source_registry.sh"

# ── Test harness ──────────────────────────────────────────────────────────────

_PASS=0
_FAIL=0

# _assert_eq <test_name> <expected> <actual>
_assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS  $name"
        (( _PASS++ )) || true
    else
        echo "  FAIL  $name"
        echo "        expected: '$expected'"
        echo "        actual:   '$actual'"
        (( _FAIL++ )) || true
    fi
}

# _assert_return0 <test_name> <command...>
_assert_return0() {
    local name="$1"; shift
    if "$@" > /dev/null 2>&1; then
        echo "  PASS  $name"
        (( _PASS++ )) || true
    else
        echo "  FAIL  $name (expected exit 0, got non-zero)"
        (( _FAIL++ )) || true
    fi
}

# _assert_return1 <test_name> <command...>
_assert_return1() {
    local name="$1"; shift
    if "$@" > /dev/null 2>&1; then
        echo "  FAIL  $name (expected non-zero, got exit 0)"
        (( _FAIL++ )) || true
    else
        echo "  PASS  $name"
        (( _PASS++ )) || true
    fi
}

# ── canonical_id_normalize ────────────────────────────────────────────────────

echo "canonical_id_normalize"

_assert_eq \
    "bare name with default=core -> core/<name>" \
    "core/git" \
    "$(canonical_id_normalize "git" "core")"

_assert_eq \
    "already canonical (user source) -> pass-through" \
    "user/myfeat" \
    "$(canonical_id_normalize "user/myfeat" "core")"

_assert_eq \
    "already canonical (external source) -> pass-through" \
    "repo-a/foo" \
    "$(canonical_id_normalize "repo-a/foo" "core")"

_assert_eq \
    "bare name with custom default source" \
    "user/tool" \
    "$(canonical_id_normalize "tool" "user")"

_assert_return1 \
    "empty name -> error" \
    canonical_id_normalize "" "core"

_assert_return1 \
    "empty default_source -> error" \
    canonical_id_normalize "git" ""

_assert_return1 \
    "nested path (a/b/c) -> invalid" \
    canonical_id_normalize "a/b/c" "core"

# ── canonical_id_validate ─────────────────────────────────────────────────────

echo "canonical_id_validate"

_assert_return0 \
    "core/git -> valid" \
    canonical_id_validate "core/git"

_assert_return0 \
    "user/myfeat -> valid" \
    canonical_id_validate "user/myfeat"

_assert_return0 \
    "external-source/tool -> valid" \
    canonical_id_validate "external-source/tool"

_assert_return1 \
    "bare name (no slash) -> invalid" \
    canonical_id_validate "git"

_assert_return1 \
    "empty string -> invalid" \
    canonical_id_validate ""

_assert_return1 \
    "nested path core/a/b -> invalid" \
    canonical_id_validate "core/a/b"

_assert_return1 \
    "leading slash (/name) -> invalid" \
    canonical_id_validate "/name"

_assert_return1 \
    "trailing slash (source/) -> invalid" \
    canonical_id_validate "source/"

# ── canonical_id_parse ────────────────────────────────────────────────────────

echo "canonical_id_parse"

src="" nm=""
canonical_id_parse "core/git" src nm
_assert_eq "core/git -> source_id=core"  "core" "$src"
_assert_eq "core/git -> name=git"        "git"  "$nm"

src="" nm=""
canonical_id_parse "user/myfeat" src nm
_assert_eq "user/myfeat -> source_id=user"    "user"    "$src"
_assert_eq "user/myfeat -> name=myfeat"       "myfeat"  "$nm"

src="" nm=""
canonical_id_parse "repo-a/foo" src nm
_assert_eq "repo-a/foo -> source_id=repo-a"   "repo-a"  "$src"
_assert_eq "repo-a/foo -> name=foo"           "foo"     "$nm"

_assert_return1 \
    "bare name passed to parse -> error" \
    canonical_id_parse "git" _dummy1 _dummy2

_assert_return1 \
    "empty string passed to parse -> error" \
    canonical_id_parse "" _dummy1 _dummy2

# ── reserved source ID constant ───────────────────────────────────────────────

echo "CANONICAL_ID_RESERVED_SOURCES"

_assert_return0 "core is in reserved list" \
    bash -c "source '$REPO_ROOT/core/lib/source_registry.sh' 2>/dev/null
             [[ \"\$CANONICAL_ID_RESERVED_SOURCES\" == *core* ]]"

_assert_return0 "user is in reserved list" \
    bash -c "source '$REPO_ROOT/core/lib/source_registry.sh' 2>/dev/null
             [[ \"\$CANONICAL_ID_RESERVED_SOURCES\" == *user* ]]"

_assert_return0 "official is in reserved list" \
    bash -c "source '$REPO_ROOT/core/lib/source_registry.sh' 2>/dev/null
             [[ \"\$CANONICAL_ID_RESERVED_SOURCES\" == *official* ]]"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"

if [[ "$_FAIL" -gt 0 ]]; then
    exit 1
fi
