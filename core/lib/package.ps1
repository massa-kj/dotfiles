# -----------------------------------------------------------------------------
# Module: package (PowerShell)
#
# DEPRECATED — Will be removed in Phase 4.
# All functions now delegate to backend_registry.ps1.
# Feature scripts should continue calling these as-is until Phase 4 migrates
# them to use backend_registry directly.
#
# Public API (Stable — preserved for compat):
#   Install-Package <Name> [Manager] [Bucket]
#   Uninstall-Package <Name> [Manager]
#   Install-Runtime <Name> <Version>
#   Uninstall-Runtime <Name> [Version]
#   Get-PackageManager
#   Test-Package <Name> [Manager]
#   Test-Runtime <Name> [Version]
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1 and logger.ps1 to be loaded by the caller.

# Source backend_registry if not already loaded
if (-not (Get-Command Resolve-BackendFor -ErrorAction SilentlyContinue)) {
    . "$env:DOTFILES_ROOT\core\lib\backend_registry.ps1"
}

# ── Package API ───────────────────────────────────────────────────────────────

# Get-PackageManager
# Return the name of the active package backend for the current platform.
function Get-PackageManager {
    return (Resolve-BackendFor -Kind "package" -Name "_default")
}

# Test-Package <Name> [Manager]
# Check if a system package is installed.
function Test-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Manager = $null
    )

    $backend = if ($Manager) { $Manager } else { Resolve-BackendFor -Kind "package" -Name $Name }
    Load-Backend -BackendId $backend
    return [bool](Backend-Call -Op "package_exists" -Args @($Name))
}

# Install-Package <Name> [Manager] [Bucket]
# Install a system package using the policy-resolved backend.
# The Bucket parameter is accepted for backwards compatibility but may be
# ignored by backends that do not support the concept.
function Install-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Manager = $null,
        [string]$Bucket = $null
    )

    $backend = if ($Manager) { $Manager } else { Resolve-BackendFor -Kind "package" -Name $Name }
    Load-Backend -BackendId $backend
    $args = if ($Bucket) { @($Name, $Bucket) } else { @($Name) }
    return (Backend-Call -Op "install_package" -Args $args) -ne 1
}

# Uninstall-Package <Name> [Manager]
# Uninstall a system package using the policy-resolved backend.
function Uninstall-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Manager = $null
    )

    $backend = if ($Manager) { $Manager } else { Resolve-BackendFor -Kind "package" -Name $Name }
    Load-Backend -BackendId $backend
    return (Backend-Call -Op "uninstall_package" -Args @($Name)) -ne 1
}

# ── Runtime API ───────────────────────────────────────────────────────────────

# Test-Runtime <Name> [Version]
# Check if a runtime version is installed via the policy-resolved backend.
function Test-Runtime {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Version = $null
    )

    $backend = Resolve-BackendFor -Kind "runtime" -Name $Name
    Load-Backend -BackendId $backend
    $args = if ($Version) { @($Name, $Version) } else { @($Name, "") }
    return [bool](Backend-Call -Op "runtime_exists" -Args $args)
}

# Install-Runtime <Name> <Version>
# Install a runtime via the policy-resolved backend and set as global default.
# Returns the concrete resolved version string.
function Install-Runtime {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Version
    )

    $backend = Resolve-BackendFor -Kind "runtime" -Name $Name
    Load-Backend -BackendId $backend
    # backend prints/returns the concrete resolved version
    return (Backend-Call -Op "install_runtime" -Args @($Name, $Version))
}

# Uninstall-Runtime <Name> [Version]
# Uninstall a runtime via the policy-resolved backend.
function Uninstall-Runtime {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Version = $null
    )

    $backend = Resolve-BackendFor -Kind "runtime" -Name $Name
    Load-Backend -BackendId $backend
    $args = if ($Version) { @($Name, $Version) } else { @($Name, "") }
    return (Backend-Call -Op "uninstall_runtime" -Args $args) -ne 1
}
