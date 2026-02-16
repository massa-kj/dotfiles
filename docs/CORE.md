# Core

Core is:

* The engine
* The safety boundary
* The orchestration brain

Features are replaceable.
Package managers are replaceable.
Platforms are replaceable.

Core must remain stable.

## Purpose

The `core/` layer provides the minimal infrastructure required to:

* Interpret profiles
* Resolve dependencies
* Orchestrate installation and removal
* Manage state safely
* Abstract package management

It must remain:

* Deterministic
* Platform-agnostic (except env bootstrap)
* Strictly layered
* Minimal in responsibility

Core is infrastructure — not business logic.

## Design Principles

### Separation of Concerns

Core must never:

* Contain feature-specific logic
* Contain OS-specific install logic
* Interpret configuration semantics
* Contain tool knowledge

Core only orchestrates and abstracts.

### Deterministic Execution

Given:

* A profile
* A state file
* A set of features

Execution must always produce the same result.

No randomness.
No hidden side effects.

### State as the Only Source of Truth

Core must:

* Read state before execution
* Update state after successful operations
* Never infer installed resources outside state

State corruption must stop execution.

## Core Modules

Current structure:

```
core/lib/
├── env
├── resolver
├── orchestrator
├── state
├── package
├── runner
├── fs
├── logger
```

The module list may evolve, but responsibility boundaries must remain stable.

## Module Responsibilities

### env

Responsibility:

* Detect and expose:

  * DOTFILES_ROOT
  * DOTFILES_PLATFORM
* Provide environment validation

Must NOT:

* Install packages
* Interpret profiles

### resolver

Responsibility:

* Load feature metadata
* Build dependency graph
* Detect cycles
* Produce topologically sorted feature list

Must NOT:

* Execute install/uninstall
* Inspect state
* Perform OS checks

resolver is pure logic.

### orchestrator

Responsibility:

* Compare desired features vs installed state
* Determine install/uninstall sets
* Execute operations in correct order

Must NOT:

* Contain package manager logic
* Access filesystem directly (except via fs)
* Modify state directly

orchestrator coordinates only.

### state

Responsibility:

* Load installed.json
* Provide read API
* Provide safe write API
* Ensure atomic updates (tmp → move)

Must enforce:

* No direct JSON manipulation outside this module
* Schema consistency
* Version awareness

State is a protected boundary.

### package

Responsibility:

* Abstract package manager differences
* Choose correct backend based on platform
* Provide stable install/remove API

Must NOT:

* Know about profiles
* Know about features
* Update state

package is a transport layer.
package abstraction exists to decouple features from backend manager decisions.

### runner

Responsibility:

* Execute shell or PowerShell scripts
* Handle exit codes consistently

Must NOT:

* Implement orchestration logic
* Perform dependency resolution

### fs

Responsibility:

* Safe file operations
* Controlled copy/symlink
* Guard against destructive paths

Must enforce:

* No root-level destructive deletion
* Explicit path handling

### logger

Responsibility:

* Structured logging
* Error reporting
* Debug output

Must NOT:

* Contain business logic

## Public API Surface

Core exposes a limited API to:

* apply.sh / apply.ps1
* feature install/uninstall scripts (indirectly)

Examples (conceptual):

State:

* state_init
* state_has_feature
* state_add_package
* state_add_file
* state_remove_feature

Package:

* install_package
* remove_package
* install_runtime
* remove_runtime

Resolver:

* resolve_features

Orchestrator:

* run_install
* run_uninstall

The exact function list may evolve,
but responsibilities must not drift.

## API Stability Levels

Core APIs are classified by stability and usage scope.

### Stable API

**Intended for external use** (features, apply scripts).

Breaking changes to these functions require:
* Documentation update
* Migration guidance
* Considered a major change

#### State Module

* `state_init`
* `state_has_feature`
* `state_add_package`
* `state_add_file`
* `state_get_packages`
* `state_get_files`
* `state_remove_feature`
* `state_list_features`

#### Package Module

* `install_package`
* `remove_package`
* `install_runtime`
* `remove_runtime`
* `has_package`
* `has_runtime`

#### Resolver Module

* `read_feature_metadata`
* `resolve_dependencies`

#### File System Module (fs)

* `ensure_dir`
* `backup_file`
* `backup_dir`
* `link_file`
* `link_dir`
* `remove_tracked_files`

#### Logger Module

* `log_debug`
* `log_info`
* `log_success`
* `log_warn`
* `log_error`
* `log_task`

#### Runner Module

* `has_command`
* `require_command`
* `run_or_die`
* `ensure_sudo`

### Internal API

**For core module use only.**

May change without external impact.

Features must not call these directly.

#### Orchestrator Module

* `read_profile`
* `calculate_diff`
* `run_install`
* `run_uninstall`

#### Environment Module (env)

* Environment variable exports only
* No public functions

### Experimental API

Currently: none.

If an unstable API is introduced, it must be:

* Marked explicitly in source comments
* Documented as experimental
* Subject to change without notice

### Deprecation Policy

Deprecated stable APIs must:

* Log warnings when called
* Remain functional for at least one minor version
* Provide migration path in documentation

## Execution Guarantees

Core guarantees:

* Dependency order correctness
* No circular dependency execution
* Idempotent state transitions
* No partial state writes

Core does NOT guarantee:

* Rollback on failure
* Recovery from external system changes
* Manager-level transactional integrity

Failure is explicit and terminal.

## Error Handling Policy

* Any failure stops execution immediately.
* No silent fallback.
* No implicit retries.
* No partial state commits.

If state update fails → abort.
If dependency cycle detected → abort.
If package install fails → abort.

Safety over convenience.

## What Core Must Never Do

* Parse feature configuration values
* Contain feature-specific branching
* Embed platform install logic
* Inspect files inside feature directories
* Write to state outside state module

If a change requires violating these rules,
the architecture must be reconsidered.

## Compatibility Expectations

Core API stability is important.

Breaking changes include:

* State schema changes
* Public function signature changes
* Execution flow reordering

When such changes are required:

* Update STATE_SPEC.md
* Provide migration guidance
* Increment state version if needed

## Future Extension Rules

When adding a new core module:

1. Define responsibility clearly.
2. Ensure it does not overlap with existing modules.
3. Avoid circular dependency between modules.
4. Keep cross-module calls minimal.

Core must remain small.
