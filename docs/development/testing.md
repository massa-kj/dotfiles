# Testing Strategy

## Test Types

Three levels of testing exist in this project:

**Unit tests** — pure function behavior (planner logic, state parsing, resolver sort)

**Integration tests** — multi-module interaction (orchestrator flow, state commit after apply)

**Environment tests** — Docker-based full installation scenarios

## Unit Tests

Unit tests cover stable public APIs and invariant-critical logic.

Target modules:
* `core/lib/planner` — classification, decision table
* `core/lib/state` — schema validation, invariants, atomic commit
* `core/lib/resolver` — topological sort, cycle detection, capability injection

Internal APIs must NOT be tested directly.
Tests must validate behavior, not implementation details.

## Integration Tests

Integration tests verify the orchestrator pipeline end-to-end with real file I/O
but without executing feature scripts.

Scenarios to cover:
* Initial install (create)
* No-op (noop)
* Version mismatch (replace)
* Feature removal (destroy)
* Dependency ordering

Test location: `tests/`

## Environment Tests

| Environment | Description |
|-------------|-------------|
| [Environment](../../tests/environment/README.md) | Full apply execution in isolated environments (Docker, Windows Sandbox) |
| [Linux (Docker)](../../tests/environment/linux/docker/README.md) | Full apply execution in a fresh Ubuntu container |
| [Windows (Sandbox)](../../tests/environment/windows/README.md) | Full apply execution in a disposable Windows Sandbox instance |

## What Must NOT Be Tested

Tests must validate behavior, not implementation details.

Do not test:
* Internal APIs (functions not listed in module public API)
* Shell-specific implementation choices (use of `mapfile`, `yq` invocation style, etc.)
* Log output format
* OS-specific branching internals
* Command syntax details

If a test breaks because of a refactor that preserves behavior, the test is testing the wrong thing.

## Breaking Changes

Tests and documentation must be updated when:
* A stable API changes signature or semantics
* The state schema changes (version bump required)
* The execution phase order changes
* The planner decision table changes

Such changes require coordinated updates: spec + test + doc in the same change.

## CI Strategy

{TODO}
