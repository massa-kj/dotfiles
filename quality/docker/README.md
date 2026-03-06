# Docker-based Testing

This directory contains Docker-based integration tests for the dotfiles system.

## Purpose

Verify dotfiles behavior in a clean, isolated environment.

Tests focus on **state guarantees** defined in STATE_SPEC.md:

* State initialization correctness
* Idempotent execution
* No duplicate resources
* Absolute path invariants

## Philosophy

These tests are **black-box tests**.

They verify:

* State structure and content
* Execution determinism
* System guarantees

They do NOT verify:

* Internal implementation details
* Specific package manager behavior
* Feature-specific configuration

State is the single source of truth.

## Test Scenarios

### minimal.sh

Verifies basic execution:

* State file is created
* Version field is correct
* Features are recorded
* No duplicates exist
* All paths are absolute

### idempotent.sh

Verifies determinism:

* Second apply does not change state
* No duplicate packages
* No duplicate files

### uninstall.sh

Verifies safe removal:

* State-tracked files are removed
* Non-tracked files are preserved (filesystem scan prohibition)
* State is properly cleaned
* Uninstall is idempotent
* No destructive operations outside state authority

### version_install.sh

Verifies version specification installation:

* Features with version configuration are installed correctly
* Version is recorded in state runtime metadata
* Packages include version information

### version_mixed.sh

Verifies mixed version/no-version features:

* Features with version specification record version in state
* Features without version specification do not record version
* Both types coexist correctly

### version_upgrade.sh

Verifies version change behavior:

* Version mismatch triggers reinstall
* Old version is removed before new installation
* State is updated with new version and package

## Quick Start

### Run all tests

```bash
./quality/docker/test.sh
```

This will:
1. Build the test image
2. Run minimal scenario
3. Run idempotent scenario
4. Run uninstall scenario
5. Run version_install scenario
6. Run version_mixed scenario
7. Run version_upgrade scenario

### Run specific test

```bash
./quality/docker/test.sh minimal
./quality/docker/test.sh idempotent
./quality/docker/test.sh uninstall
./quality/docker/test.sh version-install
./quality/docker/test.sh version-mixed
./quality/docker/test.sh version-upgrade
```

### Build image only

```bash
./quality/docker/test.sh build
```

### Clean up

```bash
./quality/docker/test.sh clean
```

### Interactive shell (for debugging)

```bash
./quality/docker/test.sh shell
```

This opens an interactive bash shell in the container. Useful for:
- Manually running bootstrap: `./platforms/linux/bootstrap.sh`
- Testing apply command: `./dotfiles apply profiles/linux.yaml`
- Inspecting state: `cat state/state.json`
- Debugging failures

## Expected Behavior

All scenarios should:

* Execute without errors
* Exit with status 0
* Print "PASSED" at the end

Any failure indicates a violation of system guarantees.

## Design Principles

### Why Docker?

* Reproducible clean environment
* No host system pollution
* Easy CI integration
* Platform consistency

### Why State-Based Verification?

From ARCHITECTURE.md:

> State is both input and output of execution.
> No other layer persists execution memory.

If state is correct, the system is correct.

### What These Tests Do NOT Cover

* Package manager availability
* Network failures
* External system changes
* Runtime state outside dotfiles scope

These are environmental concerns, not architectural guarantees.

## Adding New Scenarios

When adding new test scenarios:

1. Create `quality/docker/scenarios/<name>.sh`
2. Follow `set -euo pipefail` pattern
3. Verify state only — not implementation
4. Exit 1 on any violation
5. Print clear failure messages

Document guarantees being tested.

## File Structure

```
quality/docker/
├── Dockerfile           # Test container definition
├── test.sh              # Test execution script
├── README.md            # This file
└── scenarios/           # Test scenarios
    ├── minimal.sh       # Basic execution test
    ├── idempotent.sh    # Determinism test
    ├── uninstall.sh     # Safe removal test
    ├── version_install.sh   # Version specification test
    ├── version_mixed.sh     # Mixed version/no-version test
    └── version_upgrade.sh   # Version change test

# Note: .dockerignore is in the repository root
# (Docker requires it at the build context root)
```
