# Testing Guide

## Purpose

Testing protects architectural boundaries.

Core is the safety and orchestration layer.
Tests exist to guarantee:

- Deterministic execution
- State safety
- Stable API behavior

Testing does not exist to freeze implementation details.

(See: CORE.md, STATE_SPEC.md)

## What Must Be Tested

### 1. Stable API

All Stable APIs defined in CORE.md must be covered.

Internal APIs must NOT be tested directly.

### 2. State Invariants

State must always:

- Contain a valid version field
- Reject unknown schema versions
- Reject invalid JSON
- Avoid partial writes
- Prevent duplicate feature ownership
- Store only absolute file paths

State is the uninstall authority.
If state integrity breaks, safety breaks.

(See: STATE_SPEC.md)

### 3. Determinism

Given:

- A profile
- A state
- A feature set

Execution must produce identical results.

Test:

- Dependency order
- Idempotent execution
- Version mismatch reinstall behavior

### 4. Orchestrator Behavior

Integration tests must verify:

- Initial install
- No-op execution
- Removal flow
- Version mismatch flow
- Dependency ordering

Internal helper functions must not be tested directly.

## What Must NOT Be Tested

- Internal APIs
- Shell-specific implementation details
- jq/yq usage
- Log formatting
- OS-specific branching
- Command syntax details

Tests must validate behavior, not implementation.

## Breaking Changes

Tests must be updated if:

- Stable API changes
- State schema changes
- Execution phase order changes

Such changes require documentation updates.
