# -----------------------------------------------------------------------------
# Module: env
#
# Responsibility:
#   Define environment variables for dotfiles framework.
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Root directory of dotfiles
# Assumes this script is located at core/lib/env.ps1
$script:DOTFILES_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$global:DOTFILES_ROOT = $script:DOTFILES_ROOT

# Platform detection
$global:DOTFILES_PLATFORM = "windows"

# XDG/AppData directories
$script:UserProfileBase = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$script:ConfigBase = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $script:UserProfileBase "AppData\Roaming" }
$script:StateBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $script:UserProfileBase "AppData\Local" }
$script:DataBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $script:UserProfileBase "AppData\Local" }

$global:DOTFILES_CONFIG_HOME = Join-Path $script:ConfigBase "dotfiles"
$global:DOTFILES_STATE_HOME = Join-Path $script:StateBase "dotfiles"
$global:DOTFILES_DATA_HOME = Join-Path $script:DataBase "dotfiles"

# Get-DotfilesStateFilePath
# Return authoritative state file path.
function Get-DotfilesStateFilePath {
	return Join-Path $global:DOTFILES_STATE_HOME "state.json"
}

# Features directory
$global:DOTFILES_FEATURES_DIR = Join-Path $DOTFILES_ROOT "features"

# Profiles directory (override allowed)
if (-not (Get-Variable -Scope Global -Name DOTFILES_PROFILES_DIR -ErrorAction SilentlyContinue) -and -not $env:DOTFILES_PROFILES_DIR) {
	$global:DOTFILES_PROFILES_DIR = Join-Path $global:DOTFILES_CONFIG_HOME "profiles"
} elseif (-not (Get-Variable -Scope Global -Name DOTFILES_PROFILES_DIR -ErrorAction SilentlyContinue) -and $env:DOTFILES_PROFILES_DIR) {
	$global:DOTFILES_PROFILES_DIR = $env:DOTFILES_PROFILES_DIR
}

# Source registry file (override allowed)
if (-not (Get-Variable -Scope Global -Name DOTFILES_SOURCES_FILE -ErrorAction SilentlyContinue) -and -not $env:DOTFILES_SOURCES_FILE) {
	$global:DOTFILES_SOURCES_FILE = Join-Path $global:DOTFILES_CONFIG_HOME "sources.yaml"
} elseif (-not (Get-Variable -Scope Global -Name DOTFILES_SOURCES_FILE -ErrorAction SilentlyContinue) -and $env:DOTFILES_SOURCES_FILE) {
	$global:DOTFILES_SOURCES_FILE = $env:DOTFILES_SOURCES_FILE
}

# Backend plugins directory
$global:DOTFILES_BACKENDS_DIR = Join-Path $DOTFILES_ROOT "backends"

# Policies directory and default policy file resolution
$global:DOTFILES_POLICIES_DIR = Join-Path $global:DOTFILES_CONFIG_HOME "policies"
if (-not (Get-Variable -Scope Global -Name DOTFILES_POLICY_FILE -ErrorAction SilentlyContinue) -and -not $env:DOTFILES_POLICY_FILE) {
	$policyCandidate = Join-Path $global:DOTFILES_POLICIES_DIR "default.$($global:DOTFILES_PLATFORM).yaml"
	if (Test-Path $policyCandidate) {
		$global:DOTFILES_POLICY_FILE = $policyCandidate
	} else {
		$global:DOTFILES_POLICY_FILE = Join-Path $global:DOTFILES_POLICIES_DIR "default.yaml"
	}
} elseif (-not (Get-Variable -Scope Global -Name DOTFILES_POLICY_FILE -ErrorAction SilentlyContinue) -and $env:DOTFILES_POLICY_FILE) {
	$global:DOTFILES_POLICY_FILE = $env:DOTFILES_POLICY_FILE
}
