# Environment variable definitions

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Root directory of dotfiles
# Assumes this script is located at core/lib/env.ps1
$script:DOTFILES_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$global:DOTFILES_ROOT = $script:DOTFILES_ROOT

# Platform detection
$global:DOTFILES_PLATFORM = "windows"

# Path to state file
$global:DOTFILES_STATE_FILE = Join-Path $DOTFILES_ROOT "state" "installed.json"

# State directory
$global:DOTFILES_STATE_DIR = Join-Path $DOTFILES_ROOT "state"

# Features directory
$global:DOTFILES_FEATURES_DIR = Join-Path $DOTFILES_ROOT "features"

# Profiles directory
$global:DOTFILES_PROFILES_DIR = Join-Path $DOTFILES_ROOT "profiles"

# Export for module usage
Export-ModuleMember -Variable DOTFILES_ROOT, DOTFILES_PLATFORM, DOTFILES_STATE_FILE, DOTFILES_STATE_DIR, DOTFILES_FEATURES_DIR, DOTFILES_PROFILES_DIR
