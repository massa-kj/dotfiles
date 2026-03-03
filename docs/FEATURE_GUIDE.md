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

### Optional Fields

#### `provides` (optional)

List of capabilities this feature exposes to the resolver.

```yaml
provides:
  - name: package_manager
  - name: runtime_manager
```

Used by consumer features via `requires`.

#### `requires` (optional)

List of abstract capabilities this feature needs at install time.

```yaml
requires:
  - name: package_manager
```

The resolver finds every feature in the current profile that declares the matching `provides` entry,
and adds them as implicit install-order dependencies.

If no provider is found in the profile, `apply` aborts with an error.

### Capability Semantics

| Capability | Assigned to |
|---|---|
| `package_manager` | `brew`, `scoop`, `mise` |
| `runtime_manager` | `mise` |

Use `requires` instead of a hard-coded `depends: [brew]` when a feature only
needs _some_ package manager, not `brew` specifically.

This keeps the feature platform-agnostic and lets the profile decide which
manager is in use.

**Example — dependency chain resolved at apply time:**

```
Profile: [brew, mise, cli-tools, node, ...]

cli-tools.requires = [package_manager]
→  brew provides package_manager   →  brew added as implicit dep of cli-tools

node.requires = [runtime_manager]
→  mise provides runtime_manager   →  mise added as implicit dep of node
```

**Uninstall safety:**
Removing a provider feature from a profile while a consumer feature with a matching `requires`
remains in the profile causes `apply` to abort — the resolver detects the missing provider
before any changes are made.

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
# meta.yaml (common — platform-agnostic capability dependency)
description: Terminal multiplexer with custom configuration
depends: []

requires:
  - name: package_manager

# meta.linux.yaml (Linux/WSL — platform-specific packages)
depends: []

packages:
  - tmux
```

Platform-specific files must follow the same rules as `meta.yaml`.

Do not declare `depends: [brew]` in `meta.linux.yaml`.
Use `requires: [{name: package_manager}]` in `meta.yaml` instead.

## Dependency Rules

### What "depends" Means

`depends` indicates a direct feature-to-feature ordering constraint:

> This feature requires another specific feature to be installed first.

Use `depends` when the relationship is concrete and named (e.g., `git-tools` needs `git`).

It does NOT mean:

* Runtime coupling
* Dynamic linkage
* Conditional execution

### What "requires" Means

`requires` indicates a capability-based ordering constraint:

> This feature needs _any_ provider of this capability to be present.

Use `requires` instead of `depends: [brew]` when a feature only cares that _some_
package manager is available, not a specific one.

Capability providers are declared via `provides` by manager features (e.g., `brew`, `mise`).

### Choosing between "depends" and "requires"

| Situation | Use |
|---|---|
| Need a specific feature installed first | `depends` |
| Need any package manager | `requires: [package_manager]` |
| Need any runtime manager | `requires: [runtime_manager]` |

Dependencies should remain shallow.

Deep dependency chains indicate architectural problems.

### Circular Dependencies

Circular dependencies are invalid.

If two features appear mutually dependent,
the design must be reconsidered.

## install Responsibilities

The install script must:

1. Install required packages via the package/runtime abstraction
2. Place configuration files (copy or symlink)
3. Exit non-zero on failure

The install script must NOT:

* Register state directly (executor handles state on behalf of the feature)
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

Features must NOT:

* Access or modify installed.json directly
* Call state registration functions (executor handles all state writes)
* Infer state outside official APIs
* Attempt to repair state

State is written by the executor after each feature operation completes.
Feature scripts do not write state.

## Package Management Rules

Feature scripts interact with packages via meta.yaml declarations.
The executor reads `meta.yaml` and invokes the appropriate backend.

Features must not:

* Call `apt`, `brew`, `scoop`, `mise`, or any package manager directly inside install/uninstall scripts
* Detect package manager manually
* Hardcode platform-specific package manager commands

Package installation strategy is determined by backend and policy, not by feature scripts.
Features must remain insulated from it.

## Repository-Based Installation Rules

Some tools are not available through a package manager and must be installed
by cloning a git repository directly.

Features managing such tools must use the `repo` abstraction:

* **Bash**: `clone_repository`, `resolve_tool_path`, `is_tool_installed`
* **PowerShell**: `Clone-Repository`, `Resolve-ToolPath`, `Test-ToolInstalled`

### Conventions

Source repositories are cloned to:

* `~/.local/src/<tool>` (Bash)
* `$env:USERPROFILE\.local\src\<tool>` (PowerShell)

Tool binaries or launchers are placed in:

* `~/.local/bin/<tool>` (Bash)
* `$env:USERPROFILE\.local\bin\<tool>` (PowerShell)

### Usage Pattern

```bash
# Bash
REPO_DEST="$HOME/.local/src/my-tool"
clone_repository "$FEATURE_NAME" "https://github.com/example/my-tool.git" "$REPO_DEST"
link_file "$FEATURE_NAME" "$REPO_DEST/my-tool.sh" "$(resolve_tool_path my-tool)"
```

```powershell
# PowerShell
$RepoDir = Join-Path $env:USERPROFILE ".local\src\my-tool"
Clone-Repository -Feature $FeatureName -RepoUrl "https://github.com/example/my-tool.git" -DestPath $RepoDir
New-FileLink -Feature $FeatureName -Source "$RepoDir\launch.cmd" -Destination (Resolve-ToolPath "my-tool")
```

### Rules

Features must:

* Use `clone_repository` / `Clone-Repository` for all git-based installs
* Register the cloned directory via state (handled automatically by `clone_repository`)
* Register any placed binaries via `link_file` / `New-FileLink`

Features must not:

* Call `git` directly without going through the repo abstraction
* Clone into arbitrary paths outside conventions
* Hardcode repository paths

Uninstall is handled automatically by `remove_tracked_files` / `Remove-TrackedFiles`
because `clone_repository` registers the cloned directory in state.

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
