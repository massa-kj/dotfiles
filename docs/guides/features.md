# Feature Guide

## Purpose

This guide explains how to create and maintain a feature module.

For state interaction contracts, see `specs/data/state.md`.
For dependency resolution mechanics, see `specs/algorithms/resolver.md`.

## Feature Design Principles

One feature = one logical responsibility (one tool, one runtime, one configuration unit).

Features must be:
* **Independent** — no dependency on other features' internals
* **Deterministic** — same inputs produce same result
* **Reversible** — everything installed can be uninstalled
* **Minimal** — scope should not expand silently

If a feature grows too large, split it.
If behavior is needed in core, it belongs in core.

## Directory Structure

```
features/<name>/
├── meta.yaml
├── meta.<platform>.yaml   # optional: linux, wsl, windows
├── install.sh / install.ps1
├── uninstall.sh / uninstall.ps1
└── files/                 # configuration files, if any
```

No nested submodules. No cross-feature imports.

The same layout is used for all source roots:

* built-in: `{repo}/features/<name>/`
* user: config home `features/<name>/`
* external: data home `sources/<source_id>/features/<name>/`

## meta.yaml

```yaml
description: Brief description
depends:
  - git                    # explicit feature dependency
  - core/bash              # explicit cross-source dependency
requires:
  - name: package_manager  # capability-based dependency
provides:
  - name: package_manager  # capability this feature exposes
```

`depends` and `requires`/`provides` are for **ordering only**.
No version constraints, no conditional logic, no commands.

For platform-specific deps, use `meta.linux.yaml` / `meta.wsl.yaml` / `meta.windows.yaml`.
These are merged with `meta.yaml` during resolution.

`depends` normalization rules:

* bare dependency name means same-source dependency
* cross-source dependency must use an explicit canonical ID
* do not rely on source search order or fallback

**Choosing `depends` vs `requires`:**

| Situation | Use |
|---|---|
| Need a specific named feature first | `depends` |
| Need any package manager | `requires: [{name: package_manager}]` |
| Need any runtime manager | `requires: [{name: runtime_manager}]` |

## Dependency Model

`depends` — explicit feature-to-feature ordering. Use for concrete named dependencies.

`requires` / `provides` — capability-based ordering. Use when any provider suffices.
The resolver finds all profiles features that `provides` the capability and injects them
as implicit dependencies. If no provider is in the profile, apply aborts.

## Install Rules

The install script must:
* Install packages/runtimes via the abstraction layer (not by calling `brew`, `apt`, etc. directly)
* Place configuration files using `link_file` / `copy_file` abstractions
* Exit non-zero on failure

The install script must NOT:
* Write to state directly (`state.json`)
* Perform dependency resolution
* Detect platform manually

State is written by the executor after install completes.

## Uninstall Rules

The uninstall script must:
* Remove only resources tracked in state
* Use state APIs to retrieve tracked resources
* Exit non-zero on failure

The uninstall script must NOT:
* Remove untracked files
* Scan `files/` to discover what to remove
* Remove parent directories (unless explicitly tracked)

## File Management Rules

Configuration files must live in `features/<name>/files/`.

Use `link_file` (symlink) or `copy_file` (copy) for placement.
File operations are tracked in state automatically via the `fs` module.

## State Interaction Rules

Features must NOT access `state.json` directly.
State registration is handled by the executor after each successful feature operation.

## Version Handling

Version is passed in via `DOTFILES_FEATURE_CONFIG_VERSION`.
Features that support versioning read this variable and use it in install logic.
Features that do not support versioning ignore it.

Record installed version in state using `state_set_runtime` (for runtimes).

See `specs/data/state.md` for the runtime resource format.

## Feature Naming Guidelines

Feature names must be:
* Lowercase
* Tool-based (name of the tool, not the purpose)
* Stable identifiers that will not need to change

Avoid:
* Version-specific names (`node18`, `python3`)
* Temporary or placeholder names
* Ambiguous category names (`tools`, `utils`)

The feature name becomes part of state identity.
Renaming a feature is a breaking change requiring state migration.
Moving a feature between sources also changes its canonical ID and is therefore a breaking change.

## Feature Evolution

When modifying an existing feature:
* Maintain uninstall compatibility with the previously recorded state
* Do not change resource identifiers (`id` fields) without a migration plan
* Do not silently expand scope — if new responsibilities are needed, consider a new feature

Features must remain loosely coupled to the surrounding system.
Backend changes, state schema evolution, and platform additions must not require feature rewrites.
This loose coupling is enforced by: using abstraction APIs rather than calling tools directly,
declaring dependencies rather than assuming presence, and letting the executor own state.
