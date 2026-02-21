# dotfiles

A cross-platform, declarative environment management system.

Supports:

* Linux
* WSL
* Windows

This repository allows you to define your development environment declaratively and reproduce it safely.

## Overview

This project is built around five principles:

* **Declarative** – Profiles define what should exist.
* **Idempotent** – Safe to run repeatedly.
* **Modular** – Each tool is an independent feature.
* **Safe** – Uninstall removes only tracked resources.
* **Cross-platform** – Works across Linux, WSL, and Windows.

This is not a collection of configuration files.
It is a deterministic environment orchestration system.

## Quick Start

### Linux / WSL

```bash
git clone https://github.com/massa-kj/dotfiles.git ~/dotfiles
cd ~/dotfiles

./platforms/wsl/bootstrap.sh
./dotfiles apply profiles/wsl.yaml
```

> What gets installed by bootstrap:
> - git
> - jq (JSON processor)
> - yq (YAML processor)

### Windows

```powershell
git clone https://github.com/massa-kj/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

.\platforms\windows\bootstrap.ps1
.\dotfiles.ps1 apply profiles\windows.yaml
```

Bootstrap installs only minimal execution dependencies.

> What gets installed by bootstrap:
> - git
> - jq (JSON processor)
> - yq (YAML processor)

Feature installation is handled by `apply`.

## Using Profiles

Profiles define the desired environment.

Example:

```yaml
features:
  git: {}
  neovim: {}
  node:
    version: "22.17.1"
```

Run:

```bash
./dotfiles apply profiles/wsl.yaml
```

Profiles declare intent only.

They do not contain logic or installation details.

## Architecture

The system is structured into layers:

```
platforms → profiles → apply → core → features
                         ↓
                       state
```

* platforms prepare execution
* profiles declare intent
* apply orchestrates
* core provides infrastructure
* features implement tools
* state records installed resources

For full design documentation, see [this section](#design-documents).

### Safety Model

Uninstall operations remove only resources recorded in state.

The system never scans the filesystem to infer what to delete.

State is the only authority.

See `STATE_SPEC.md` for details.

### Extending the System

To create a new feature:

```
features/mytool/
├── meta.yaml
├── install.sh
├── uninstall.sh
└── files/
```

Declare dependencies in `meta.yaml`:

```yaml
depends:
  - git
```

Use package abstraction and state APIs.

See `FEATURE_GUIDE.md` for full guidelines.

## Documentation

### Design Documents

* **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** – System design and layer responsibilities
  * Read this to understand *why* the system is structured this way
  * Covers: layer boundaries, data flow, architectural constraints

* **[CORE.md](docs/CORE.md)** – Core module responsibilities and API stability
  * Read this to understand infrastructure primitives and stability guarantees
  * Covers: module responsibilities, API classification, extension rules

* **[FEATURE_GUIDE.md](docs/FEATURE_GUIDE.md)** – Feature implementation rules
  * Read this to create or modify features
  * Covers: feature structure, meta.yaml rules, state interaction

* **[STATE_SPEC.md](docs/STATE_SPEC.md)** – State schema and safety model
  * Read this to understand state format and uninstall safety
  * Covers: JSON schema, invariants, versioning policy

### Writing Guidelines

* **[DOCUMENTATION_GUIDE.md](docs/DOCUMENTATION_GUIDE.md)** – Documentation structure policy
  * Read this before updating documentation
  * Covers: what to document where, stability vs implementation
