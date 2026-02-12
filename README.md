# dotfiles

A cross-platform, declarative dotfiles management system supporting Linux, WSL, and Windows.

- **Declarative**: Define my environment in YAML profiles
- **Idempotent**: Safe to run multiple times
- **Modular**: Features are self-contained units
- **Dependency-aware**: Automatic dependency resolution
- **Safe uninstall**: State tracking for clean removal
- **Cross-platform**: Linux, WSL, and Windows support

## Quick Start

### Linux / WSL

```bash
# 1. Clone repository
git clone https://github.com/massa-kj/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Run bootstrap
./platforms/wsl/bootstrap.sh

# 3. Apply profile
./apply.sh profiles/wsl.yaml
```

### Windows

```powershell
# 1. Clone repository
git clone https://github.com/massa-kj/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles

# 2. Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 3. Run bootstrap
.\platforms\windows\bootstrap.ps1
# What gets installed:
# - git
# - jq (JSON processor)
# - yq (YAML processor)

# 4. Apply profile
.\apply.ps1 profiles\windows.yaml
```

## Architecture

### Directory Structure

```
dotfiles/
├── core/lib/           # Core libraries (bash & PowerShell)
├── features/           # Self-contained feature modules
│   ├── git/
│   │   ├── meta.yaml             # Dependencies and metadata
│   │   ├── meta.{platform}.yaml  #
│   │   ├── install.sh            # Linux/WSL installer
│   │   ├── install.ps1           # Windows installer
│   │   ├── uninstall.sh          # Linux/WSL uninstaller
│   │   ├── uninstall.ps1         # Windows uninstaller
│   │   └── files/                # Configuration files
│   └── ...
├── platforms/          # Platform-specific bootstrap
│   ├── wsl/
│   └── windows/
├── profiles/           # Declarative environment definitions
│   ├── dev.yaml
│   └── windows.yaml
├── state/              # Installation state (tracked)
├── apply.sh            # Entry point (Linux/WSL)
└── apply.ps1           # Entry point (Windows)
```

### Design Philosophy

See [](.md) for detailed design documentation.

**Core Principles:**
- Separation of declaration (profiles) and implementation (features)
- State as single source of truth
- Platform differences isolated in bootstrap layer
- Features are fully self-contained

## Features

### Available Features

- **Development Tools**: git, git-tools (lazygit), neovim, vscode
- **Languages**: node, python, rust, lua
- **Package Managers**: brew (Linux/macOS), scoop (Windows), mise
- **Shells**: bash, powershell
- **Terminal**: tmux (Linux/WSL)
- ...

### Creating Custom Features

1. Create feature directory:
   ```bash
   mkdir -p features/myfeature/files
   ```

2. Define metadata (`features/myfeature/meta.yaml`):
   ```yaml
   depends:
     - git  # Optional dependencies
   ```

3. Implement installers:
   - `install.sh` / `install.ps1` - Installation logic
   - `uninstall.sh` / `uninstall.ps1` - Cleanup logic

4. Add to profile:
   ```yaml
   features:
     - myfeature
   ```

See existing features for implementation examples.
