# State Specification

## Scope

This document defines the normative contract for state.

Covered: schema, resource kinds, identity rules, invariants, state transition rules,
atomic commit rules, safety rules, and compatibility.

Not covered: profile semantics, policy semantics, planner rules, backend selection.

## Purpose

State is the **single authority** for:

1. What resources were created by dotfiles execution.
2. What resources are safe to remove.
3. What backend must be used for deterministic removal.

State contains effects only. No desired state. No policy. No dependency graphs.

## File Location

Core locates the state directory via:

1. `DOTFILES_STATE_DIR` environment variable, if set and non-empty.
2. Otherwise: `${DOTFILES_ROOT}/state`

Authoritative file: `${STATE_DIR}/state.json`

* Must be JSON encoded in UTF-8.
* `${STATE_DIR}` must be created if missing.
* `state.json` must be created (empty state) if missing.

## Schema

```json
{
  "version": 2,
  "features": {
    "<feature_id>": {
      "resources": [ <resource_entry>, ... ]
    }
  }
}
```

`version` must be `2`. `features` must be an object.

### Resource kinds

**`package`**

```json
{
  "kind": "package",
  "id": "pkg:<name>",
  "backend": "<backend_id>",
  "package": { "name": "<string>", "version": "<string|null>" }
}
```

`version: null` means unknown or unpinned — not "latest".

**`runtime`**

```json
{
  "kind": "runtime",
  "id": "rt:<name>@<version>",
  "backend": "<backend_id>",
  "runtime": { "name": "<string>", "version": "<string>" }
}
```

**`fs`**

```json
{
  "kind": "fs",
  "id": "fs:<logical_id>",
  "fs": {
    "path": "<absolute_path>",
    "entry_type": "file|dir|symlink|junction",
    "op": "copy|link"
  }
}
```

`fs` resources must NOT contain `backend`.
`fs.path` must be absolute. `logical_id` must be stable within a feature.

## Identity Rules

Within a single feature: `resource.id` must be unique.
Across features: the pair `(feature_id, resource.id)` must be unique.
The same `fs.path` must NOT be recorded by multiple features.

## Invariants

Core must validate all invariants before execution. If any fails, execution must abort.

1. `version` must be `2`.
2. `features` must be an object.
3. Each feature entry must contain a `resources` array.
4. Each resource must have a valid `kind` and matching kind payload.
5. Within a feature: no duplicate `resource.id`.
6. Across all features: no duplicate `fs.path`.
7. All `fs.path` values must be absolute.
8. State must reflect only successfully completed operations.

## State Transition Rules

1. State must be initialized before any execution.
2. State must be updated only after a successful feature-level operation.
3. State must not be partially written.
4. If execution fails, state must remain unchanged.
5. Uninstall must operate strictly on recorded resources.
6. Only the state module may write authoritative state.

## Atomic Commit Rules

`state_commit_atomic(new_state)` must:

1. Write to `state.json.tmp`
2. Validate JSON parse
3. Validate invariants in load mode
4. Replace `state.json` via atomic rename
5. Remove temp file on success

Direct in-place edits are forbidden.
Commit unit is a single feature operation (install or uninstall of one feature).

## Safety Rules

Core must remove **only** resources recorded in state.

Core must NOT:
* scan the filesystem to discover removal targets
* infer backends for resources without a backend record

For `package`/`runtime` removal: use the recorded `backend`. If the backend cannot be loaded, abort.

For `fs` removal: remove only the exact tracked `fs.path`. Must not remove parent directories
unless the parent is itself explicitly tracked as a `fs` resource with `entry_type: dir`.

**Destructive path guards** — The fs module must refuse removal of dangerous paths even if recorded:

* Linux/WSL: `/`, `/home`, `/usr`, `/etc`, `/var`, `/bin`, `/sbin`, `/opt`
* Windows: `C:\`, `C:\Windows`, `C:\Program Files`, `C:\Program Files (x86)`, user profile root

## Corruption Handling

If `state.json` cannot be parsed as JSON, is not UTF-8, has unknown/missing `version`,
or fails invariant checks: execution must abort. Automatic repair must NOT be performed.

## Unknown Kind Handling

Load mode: tolerate unknown `kind` values (preserve raw JSON, enforce structural validity).
Execute mode: reject execution of any feature containing an unknown `kind`.
Other features are not blocked unless they depend on the blocked feature.

## Compatibility

v1 state may be read for migration. Executing with v1 state requires an explicit migration path.
Post-migration state must be v2.

A `migrate-state` command (or equivalent) must be side-effect free, back up existing state,
validate the migrated result, and commit atomically.

## Prohibited Content

State must NOT contain: profile content, policy content, dependency graphs,
runtime environment variables, or arbitrary plugin-defined keys at feature level.

Plugins must not write arbitrary extensions into state directly.
Extension requires adding a new kind and updating core validation.
