# dotfiles.ps1
# Main CLI entry point for dotfiles management

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot = $PSScriptRoot
$global:DOTFILES_ROOT = $ScriptRoot

# Load logger for error messages
. "$ScriptRoot\core\lib\logger.ps1"

# Usage
function Show-Usage {
    Write-Host @"
Usage: dotfiles.ps1 <command> [options]

A declarative environment management system.

Available commands:
  apply <profile>    Apply a dotfiles profile

Examples:
  .\dotfiles.ps1 apply profiles\windows.yaml
  .\dotfiles.ps1 apply profiles\minimal.yaml

"@
    exit 1
}

# Parse command
if ($args.Count -lt 1) {
    Show-Usage
}

$Command = $args[0]
$CommandArgs = $args[1..($args.Count - 1)]

# Dispatch to command implementation
switch ($Command) {
    "apply" {
        & "$ScriptRoot\cmd\apply.ps1" @CommandArgs
        exit $LASTEXITCODE
    }
    "help" {
        Show-Usage
    }
    "--help" {
        Show-Usage
    }
    "-h" {
        Show-Usage
    }
    default {
        Log-Error "Unknown command: $Command"
        Write-Host ""
        Show-Usage
    }
}
