# Feature Guide

Features are:

* Replaceable
* Independent
* Minimal
* Safe

Core orchestrates.
Profiles declare.
Features implement.

If feature complexity grows beyond its scope,
the architecture should be revisited.

## Purpose

A feature represents a **self-contained unit of environment configuration**.

One feature should correspond to:

* One tool
* One runtime
* One cohesive configuration responsibility

Features must be:

* Independent
* Deterministic
* Reversible
* Minimal in scope

A feature is an implementation unit — not an orchestration layer.

## Feature Design Principles

### One Tool = One Feature

Each feature should manage exactly one logical responsibility.

Examples:

* `git`
* `neovim`
* `node`
* `tmux`

Avoid:

* Multi-tool bundles
* Cross-cutting utility features
* Hidden meta-features

If a feature grows too large, split it.

### Self-Contained

A feature must include everything required to:

* Install its tool
* Configure its files
* Remove everything it created

It must not depend on:

* External scripts
* Global assumptions
* Other feature internals

Only declared dependencies are allowed.

### Install / Uninstall Symmetry

Every feature must implement:

* `install`
* `uninstall`

These must be logically reversible.

Anything created during install must be removable via uninstall.

No exceptions.

## Directory Structure

A feature must follow this structure:

```
features/<name>/
├── meta.yaml
├── install.sh / install.ps1
├── uninstall.sh / uninstall.ps1
└── files/
```

Only these elements are allowed.

No nested submodules.
No cross-feature imports.

## meta.yaml Rules

`meta.yaml` defines feature metadata and dependencies.

### Required Fields

```yaml
description: Brief description of what this feature provides
depends:
  - git
```

#### `description` (required)

A single-line summary of the feature's purpose.

Used for documentation and future tooling.

#### `depends` (required)

List of feature dependencies.

Empty array if no dependencies.

### Metadata Extension Policy

Additional metadata fields MAY be added for documentation or tooling purposes.

Fields not used by core execution logic are permitted.

Core ignores unknown fields — they do not affect execution.

This allows future extension without breaking existing features.

### Not Allowed

The following are prohibited:

* OS branching logic
* Version constraints
* Package manager specification
* Commands or scripts
* Conditional execution logic

meta.yaml is declarative metadata — not configuration or code.

### Platform-Specific Metadata

For platform-specific dependencies, create:

* `meta.linux.yaml`
* `meta.wsl.yaml`
* `meta.windows.yaml`

These are merged with `meta.yaml` during resolution.

#### Fallback Resolution

The resolver applies platform-specific fallback logic:

* **WSL**: `meta.wsl.yaml` → `meta.linux.yaml` → `meta.yaml`
* **Linux**: `meta.linux.yaml` → `meta.yaml`
* **Windows**: `meta.windows.yaml` → `meta.yaml`

This allows:

* Sharing common Linux/WSL configuration via `meta.linux.yaml`
* WSL-specific overrides via `meta.wsl.yaml` when needed

Example:

```yaml
# meta.yaml (common)
description: Neovim text editor with custom configuration
depends:
  - git

# meta.linux.yaml (Linux/WSL common)
depends:
  - brew
```

Platform-specific files must follow the same rules as `meta.yaml`.

## Dependency Rules

### What "depends" Means

`depends` indicates:

> This feature requires another feature to be installed first.

It does NOT mean:

* Runtime coupling
* Dynamic linkage
* Conditional execution

Dependencies should remain shallow.

Deep dependency chains indicate architectural problems.

### Circular Dependencies

Circular dependencies are invalid.

If two features appear mutually dependent,
the design must be reconsidered.

## install Responsibilities

The install script must:

1. Install required packages via `package` abstraction
2. Place configuration files (copy or symlink)
3. Register created resources in state
4. Exit non-zero on failure

The install script must NOT:

* Modify state directly via JSON tools
* Bypass package abstraction
* Perform dependency resolution
* Detect platform manually

Install logic must remain deterministic.

## uninstall Responsibilities

The uninstall script must:

1. Read resources from state
2. Remove only recorded resources
3. Avoid scanning `files/`
4. Exit non-zero on failure

The uninstall script must NOT:

* Remove untracked files
* Remove global directories
* Attempt automatic discovery

Uninstall safety is more important than completeness.

## File Management Rules

All configuration files must reside inside:

```
features/<name>/files/
```

Install may:

* Copy files
* Create symlinks
* Generate minimal derived files

Install must not:

* Modify unrelated directories
* Perform global destructive actions

The `fs` abstraction should be used for file operations.

## State Interaction Rules

Features must:

* Use provided state APIs only
* Register packages and files after successful operations

Features must not:

* Access or modify installed.json directly
* Infer state outside official APIs
* Attempt to repair state

State is managed centrally.

## Package Management Rules

Features must:

* Use `install_package`, `remove_package`
* Use `install_runtime`, `remove_runtime` where appropriate

Features must not:

* Call `apt`, `brew`, `scoop`, or `mise` directly
* Detect package manager manually
* Hardcode platform-specific commands

Package strategy may change in the future.
Features must remain insulated from it.

## Idempotency Expectations

Running install twice must not:

* Duplicate files
* Corrupt configuration
* Produce inconsistent state

Running uninstall twice must not:

* Fail catastrophically
* Remove unintended resources

Features should tolerate repeated execution safely.

## What a Feature Must Never Do

A feature must never:

* Resolve dependencies
* Interpret profiles
* Modify other features
* Access global variables not provided by env
* Perform destructive filesystem operations outside its scope
* Write to state outside state APIs

If such behavior is required,
the change likely belongs in core.

## Feature Evolution

When modifying an existing feature:

* Maintain uninstall compatibility
* Avoid breaking state expectations
* Avoid changing resource tracking structure
* Avoid expanding scope silently

If scope expansion is necessary:

* Consider creating a new feature instead
* Provide migration guidance

## Feature Naming Guidelines

Feature names should be:

* Lowercase
* Tool-based
* Stable identifiers

Avoid:

* Version-specific names
* Temporary names
* Ambiguous categories

The feature name becomes part of state identity.

## Version Handling

Features can support version specification through profile configuration.

### Reading Version from Profile

Features receive configuration via the `DOTFILES_FEATURE_CONFIG_VERSION` environment variable during installation.

### Recording Version in State

After successful installation, record the version in state using `state_set_runtime` / `State-SetRuntime` API.

### When to Use Version

Version specification is most useful for:

* **Runtime environments**: node, python, rust, lua
* **Tools with breaking changes**: neovim, tmux
* **Version-sensitive workflows**: CI/CD, team consistency

Not recommended for:

* Configuration-only features (git, bash)
* System packages without version management
* Features using package managers without version support

### Version Mismatch Behavior

When a feature's version in the profile differs from the installed version in state:

1. Orchestrator detects version mismatch
2. Feature is added to reinstall list
3. Uninstall runs (removes old version)
4. Install runs (installs new version)

This ensures clean version transitions.

### Version Handling Rules

1. **Core is version-agnostic**: Dependency resolution ignores versions
2. **Features interpret versions**: Core only passes the string
3. **Optional field**: Features work without version support
4. **State records effects**: Version is recorded as installed, not desired

## Platform Differences

If platform-specific logic is required:

* It must be implemented inside install/uninstall
* It must rely on environment variables (e.g., DOTFILES_PLATFORM)
* It must not duplicate bootstrap logic

Platform abstraction belongs to core.
Feature may only branch minimally.

## Future-Proofing Rules

A feature must assume:

* Package backend may change
* Runtime manager may change
* State schema may evolve
* Platform set may expand

Feature design must remain loosely coupled.
