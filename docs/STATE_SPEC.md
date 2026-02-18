# State Spec

State is:

* The safety boundary
* The uninstall authority
* The execution memory

Without state, the system becomes unsafe.
With an unstable state, the system becomes unpredictable.

State must remain simple.

## Purpose

The state file is the **single source of truth** for installed resources.

It defines:

* What has been installed
* What is safe to remove
* What must not be touched

State exists to guarantee:

* Safe uninstall
* Deterministic execution
* Idempotency
* Operational safety

State is not a cache.
State is not a convenience layer.
State is an authority boundary.

## Location

The state file must be stored at:

```
state/installed.json
```

No alternative locations are allowed.

The directory must be version-controlled (structure only),
but `installed.json` itself may or may not be tracked depending on policy.

## Format

The state file is JSON.

YAML is intentionally not used to avoid ambiguity and to ensure strict machine parsing.

## Schema

Current schema version: **1**

```json
{
  "version": 1,
  "features": {
    "feature_name": {
      "packages": [],
      "files": []
    }
  }
}
```

> State intentionally does not record package backend to preserve manager replaceability.

### Top-Level Fields

#### `version` (integer)

Indicates the schema version.

* Must be present.
* Must be validated before execution.
* Unknown versions must stop execution.

#### `features` (object)

A map of feature name → installed resources.

Each feature entry must contain only resources created by that feature.

### Feature Entry

Each feature object may contain:

#### `packages` (array of strings)

Names passed to package abstraction during install.

Used for safe removal.

#### `files` (array of strings)

Absolute paths of files or symlinks created during install.

Only these paths may be removed during uninstall.

#### `runtime` (object, optional)

Runtime metadata for the feature.

Used to track version information and other runtime state.

**Fields**:
* `version` (string, optional): Installed version of the feature

**Example**:
```json
{
  "version": 1,
  "features": {
    "node": {
      "packages": ["node@20"],
      "files": [],
      "runtime": {
        "version": "20"
      }
    },
    "git": {
      "packages": ["git"],
      "files": ["/home/user/.gitconfig"]
    }
  }
}
```

**Backward Compatibility**:
* Runtime field is optional
* Features without runtime metadata remain valid
* State version remains 1 (backward-compatible extension)

### Schema Constraints

* No nested objects beyond defined structure.
* No arbitrary keys.
* No feature cross-references.
* No implicit defaults.

If new fields are introduced, the version must increment.

## Invariants

The following must always hold:

1. Every installed feature must exist in `features`.
2. Every path in `files` must be absolute.
3. No duplicate entries.
4. No resource may belong to multiple features.
5. State must reflect only successfully completed installs.

If any invariant is violated, execution must stop.

## State Lifecycle

### Initialization

If `installed.json` does not exist:

* It must be created with version field.
* It must contain an empty `features` object.

### During Install

Install flow:

1. Feature install runs.
2. If successful:

   * Register packages
   * Register files
   * Commit feature entry atomically

State must not be updated incrementally.

Partial writes are forbidden.

### During Uninstall

Uninstall flow:

1. Read feature entry.
2. Remove only recorded resources.
3. Remove feature entry.
4. Write updated state atomically.

Uninstall must never:

* Scan filesystem
* Infer resources dynamically

## Atomicity Requirements

All writes must:

* Use temporary file
* Validate JSON
* Replace original via atomic move

Direct in-place writes are forbidden.

If write fails:

* Abort immediately.
* Do not attempt repair.

## Corruption Handling

If state:

* Cannot be parsed
* Has invalid version
* Violates schema

Execution must stop.

Automatic repair is forbidden.

Manual intervention is required.

## Versioning Policy

Schema changes fall into two categories:

### Backward-Compatible Changes

Examples:

* Adding optional fields

No version bump required if:

* Old schema remains valid
* Core tolerates absence of new fields

### Breaking Changes

Examples:

* Structural modification
* Field renaming
* Removal of fields

Must:

* Increment version
* Provide migration guidance
* Update STATE_SPEC.md

Unknown versions must abort execution.

## What State Is Not

State must not contain:

* Configuration values
* Profile data
* Dependency graph
* Platform metadata
* Runtime options
* Environment variables

State records effects, not intent.

Profiles define intent.

## Safety Rules

State guarantees:

* Only tracked resources are removed
* Nothing outside recorded paths is touched

State does not guarantee:

* External system consistency
* Package manager rollback
* Runtime state restoration

State is a boundary of responsibility, not a transaction system.

## Future Extension Guidelines

If extending schema:

1. Keep structure flat.
2. Avoid deep nesting.
3. Avoid coupling between features.
4. Preserve uninstall determinism.

If extension increases complexity significantly,
reconsider architectural approach.
