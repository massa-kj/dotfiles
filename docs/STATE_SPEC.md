# State Spec

## Scope

This document defines the **normative contract** for `state`:

* **Schema**
* **Invariants**
* **Load / Validate / Commit / Corruption behavior**
* **Uninstall safety rules**
* **Unknown resource handling**

This document does **NOT** define:

* profile semantics
* policy semantics
* planner rules
* backend selection logic

## Purpose

State is the **single authority** for:

1. What resources were created by dotfiles execution.
2. What resources are safe to remove.
3. What backend must be used for deterministic removal (for resources that require it).

State MUST contain **effects only**.

## Location

### Canonical state directory

Core MUST locate the state directory via:

1. `DOTFILES_STATE_DIR` environment variable, if set and non-empty.
2. Otherwise, default to: `${DOTFILES_ROOT}/state`

### Canonical state file

The authoritative state file MUST be:

* `${STATE_DIR}/installed.json`

No other file is authoritative for execution.

### Requirements

* `${STATE_DIR}` MUST be created if missing.
* `${STATE_DIR}/installed.json` MUST be created if missing (initialized state).

### File Format

* State MUST be JSON encoded in UTF-8.
* YAML MUST NOT be used.

## Schema

### Top-level

```json
{
  "version": 2,
  "features": {
    "<feature_id>": {
      "resources": [
        {
          "kind": "package",
          "id": "pkg:<name>",
          "backend": "<backend_id>",
          "package": {
            "name": "<string>",
            "version": "<string|null>"
          }
        },
        {
          "kind": "runtime",
          "id": "rt:<name>@<version>",
          "backend": "<backend_id>",
          "runtime": {
            "name": "<string>",
            "version": "<string>"
          }
        },
        {
          "kind": "fs",
          "id": "fs:<logical_id>",
          "fs": {
            "path": "<absolute_path>",
            "entry_type": "file|dir|symlink|junction",
            "op": "copy|link"
          }
        }
      ]
    }
  }
}
```

### Field requirements

#### `version` (integer)

* MUST exist.
* MUST equal `2` for this schema.

#### `features` (object)

* MUST exist.
* Key MUST be `<feature_id>` (string).
* Value MUST be a feature entry object.

#### Feature entry

* MUST be an object.
* MUST contain `resources` (array).
* MUST NOT contain arbitrary keys not specified by this spec.

#### Resource entry (common)

Every resource entry MUST:

* be an object
* contain `kind` (string)
* contain `id` (string)
* contain exactly one of the kind payload keys:

  * if kind=package → `package`
  * if kind=runtime → `runtime`
  * if kind=fs → `fs`

## Resource kinds

### `package`

Required fields:

* `kind`: MUST be `"package"`
* `id`: MUST be `"pkg:<name>"` where `<name>` equals `package.name`
* `backend`: MUST exist and MUST be non-empty string
* `package.name`: MUST be non-empty string
* `package.version`: MUST exist and MUST be either string or null

Notes:

* `package.version = null` means “unknown or not pinned”; it does NOT mean “latest”.

### `runtime`

Required fields:

* `kind`: MUST be `"runtime"`
* `id`: MUST be `"rt:<name>@<version>"` where `<name>` equals `runtime.name` and `<version>` equals `runtime.version`
* `backend`: MUST exist and MUST be non-empty string
* `runtime.name`: MUST be non-empty string
* `runtime.version`: MUST be non-empty string

### `fs`

Required fields:

* `kind`: MUST be `"fs"`
* `id`: MUST be `"fs:<logical_id>"` (logical id is implementation-defined but MUST be stable within a feature)
* `fs.path`: MUST be an absolute path

  * Linux/WSL: MUST start with `/`
  * Windows: MUST be absolute (e.g. `C:\...`), and MUST NOT be relative
* `fs.entry_type`: MUST be one of: `file | dir | symlink | junction`
* `fs.op`: MUST be one of: `copy | link`

Constraints:

* `fs` resources MUST NOT contain `backend`.

  * Rationale: removal is performed by `fs` module with tracked-path rules; backend selection is not applicable.

## Identity & Uniqueness Rules

### Feature identity

* `<feature_id>` MUST be stable and MUST NOT include version (multi-version is represented by resources).

### Resource identity

Within a single feature:

* `resource.id` MUST be unique among that feature’s `resources` array.

Across different features:

* Duplicate `resource.id` MAY exist (because `fs:<logical_id>` is feature-scoped).
* However, the pair `(feature_id, resource.id)` MUST be unique in the entire state.

### No cross-feature ownership

* The same real-world entity (e.g., the same `fs.path`) MUST NOT be recorded by multiple features.
* Validation MUST reject state where two different features contain `fs.path` equal to the same string.

(Reason: uninstall safety boundary depends on single owner.)

## Invariants

Core MUST validate all invariants before execution.

1. `version` MUST be 2.
2. `features` MUST be an object.
3. Each feature entry MUST contain `resources` array.
4. Each resource MUST have a valid `kind` and kind-specific payload.
5. Within a feature: no duplicate `resource.id`.
6. Across all features: no duplicate `fs.path`.
7. All `fs.path` MUST be absolute.
8. State MUST reflect **only successfully completed operations**:

   * Partial resource recording is forbidden for a single applied operation unit.

If any invariant fails, execution MUST abort (see [this](#corruption--invalid-state-behavior)).

## State Transition Rules

1. State MUST be initialized before any execution.
2. State MUST be updated only after a successful feature-level operation.
3. State MUST NOT be partially written.
4. If execution fails, state MUST remain unchanged.
5. Uninstall MUST operate strictly on recorded resources.
6. Only the state module may write authoritative state.

## Unknown kinds handling (tolerant load, strict execution)

### Load rule

* State loader MUST be tolerant: it MUST be able to parse and keep unknown `kind` resources in memory (raw JSON preserved), as long as JSON is valid.

### Validation rule

* `state_validate(mode=load)`:

  * MUST allow unknown `kind`.
  * MUST still enforce JSON validity and structural sanity (e.g., must have `kind` and `id`).

* `state_validate(mode=execute)`:

  * MUST reject execution of any feature that contains an unknown `kind`.
  * MUST NOT abort execution of unrelated features solely because unknown kinds exist elsewhere.
    * If a feature is blocked due to unknown kind, any feature that depends on it MUST also be blocked.

### Execution rule

* Any command that would modify system state (apply/uninstall/migrate-backend) MUST run validation in `execute` mode.
* When a feature is blocked due to unknown kind:

  * the command MUST report which feature is blocked and which unknown kinds were found.
  * the command MUST continue for other features (unless user requested strict-all mode; if such a mode exists, it MUST be explicit).

## Safety rules for uninstall/removal

### General rule

Core MUST remove **only** resources recorded in state.

Core MUST NOT:

* scan the filesystem to “discover” removal targets
* infer backends for resources that lack backend record

### Package/runtime removal backend determinism

For `package` and `runtime` resources:

* Removal MUST use the `backend` recorded in the resource entry.
* If the backend plugin cannot be loaded:

  * removal MUST abort for that resource (and the feature), unless an explicit user override exists (override MUST be explicit, never implicit).

### FS removal scope

For `fs` resources:

* Core MUST only remove the exact tracked `fs.path`.
* Core MUST NOT remove parent directories unless:

  * the parent directory itself is explicitly tracked as a `fs` resource and its `entry_type` is `dir`.

### Destructive path guards (mandatory)

The fs module MUST refuse removal for dangerous paths, even if recorded, unless an explicit “force” mode exists.

At minimum, the following MUST be blocked:

* Linux/WSL: `/`, `/home`, `/usr`, `/etc`, `/var`, `/bin`, `/sbin`, `/opt` (and their direct drive roots)
* Windows: `C:\`, `C:\Windows`, `C:\Program Files`, `C:\Program Files (x86)`, user profile root (e.g. `C:\Users\<name>\`)
  (Exact list may be extended; it MUST be conservative.)

If a blocked path exists in state, execution MUST abort with a clear error.

## Corruption / Invalid state behavior

### Parse failures

If `installed.json`:

* cannot be parsed as JSON
* is not UTF-8
  then execution MUST abort.

Automatic repair MUST NOT be performed.

### Schema/version failures

If `version` is missing or unknown:

* execution MUST abort.

### Invalid invariants

If invariants fail:

* execution MUST abort.

### Recovery guidance (non-automatic)

Core MAY print guidance:

* where the state file is
* which validation rule failed
* suggestion to restore from backups (if present)

Core MUST NOT silently continue.

## Atomic commit rules

### Commit unit

Commit unit MUST be a single feature operation
(install or uninstall of one feature).

State MUST NOT be partially written.

### Algorithm

`state_commit_atomic(new_state)` MUST:

1. Write to `${STATE_DIR}/installed.json.tmp`
2. Validate JSON parse
3. Validate invariants in `load` mode (and optionally in `execute` mode if writing only known kinds)
4. Replace `${STATE_DIR}/installed.json` with an atomic rename/move
5. Remove temp file on success (or leave only if crash occurs)

Direct in-place edits are forbidden.

### Optional generation storage

If generations are implemented, it MUST still preserve:

* a single authoritative pointer file (`installed.json` or `current` → `installed.json` mapping)
* atomic pointer switch

(Generation storage is implementation detail; this spec does not require it.)

## Backward compatibility

### v1 state support

Core MAY support reading v1 state for migration purposes, but:

* executing with v1 state MUST be an explicit migration path
* post-migration state MUST be v2

### Migration command requirements (if provided)

A `migrate-state` command (or equivalent) MUST:

* be side-effect free (no install/uninstall)
* backup existing state before writing
* validate migrated result
* commit atomically

## Prohibited content in state (MUST NOT)

State MUST NOT contain:

* profile content (desired state)
* policy content (how to decide backends)
* dependency graphs
* runtime environment variables
* arbitrary plugin-defined keys at feature level

Plugins MUST NOT write arbitrary extensions into state directly.

If extension is required, it MUST be done by:

* adding a new kind and updating core validation, or
* storing plugin-private data outside authoritative state (not specified here)

## Minimal examples

### Minimal empty state

```json
{ "version": 2, "features": {} }
```

### Single feature with package + fs

```json
{
  "version": 2,
  "features": {
    "git": {
      "resources": [
        {
          "kind": "package",
          "id": "pkg:git",
          "backend": "brew",
          "package": { "name": "git", "version": null }
        },
        {
          "kind": "fs",
          "id": "fs:gitconfig",
          "fs": {
            "path": "/home/user/.gitconfig",
            "entry_type": "file",
            "op": "link"
          }
        }
      ]
    }
  }
}
```
