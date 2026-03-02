# -----------------------------------------------------------------------------
# Module: backend_registry
#
# Responsibility:
#   Resolve, load, and dispatch backend plugin operations.
#   Acts as the sole stable gate between core and backend execution adapters.
#
# Public API (Stable):
#   Backend-Registry-LoadPolicy [PolicyFile]
#   Resolve-BackendFor <Kind> <Name>
#   Load-Backend <BackendId>
#   Backend-Call <Op> <Args...>
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1 and logger.ps1 to be loaded by the caller.

# ── Private state ─────────────────────────────────────────────────────────────

# Cached parsed policy object.
$script:BrPolicyData = $null

# ID of the currently loaded backend plugin.
$script:BrLoadedBackend = ""

# ── Policy loading ────────────────────────────────────────────────────────────

# Backend-Registry-LoadPolicy [PolicyFile]
# Load policy YAML into memory cache.
# Uses DOTFILES_POLICY_FILE if no argument is given.
function Backend-Registry-LoadPolicy {
    param([string]$PolicyFile = "")

    $file = if ($PolicyFile) { $PolicyFile } else { $global:DOTFILES_POLICY_FILE }

    if (-not $file) { return }

    if (-not (Test-Path $file)) {
        Log-Warn "Backend-Registry-LoadPolicy: policy file not found: $file (using platform defaults)"
        return
    }

    # Parse YAML via yq into JSON, then into a PS object
    try {
        $json = & yq eval '.' -o=json $file 2>$null
        $script:BrPolicyData = $json | ConvertFrom-Json
    } catch {
        Log-Warn "Backend-Registry-LoadPolicy: failed to parse policy file: $_"
    }
}

# ── Backend resolution ────────────────────────────────────────────────────────

# Resolve-BackendFor <Kind> <Name>
# Return the backend_id for the given kind/name pair.
# Resolution order:
#   1. Policy overrides: .<kind>.overrides.<name>.backend  (resource name, not feature name)
#   2. Policy default:   .<kind>.default_backend
#   3. Platform default (hardcoded)
function Resolve-BackendFor {
    param(
        [Parameter(Mandatory=$true)] [string]$Kind,
        [Parameter(Mandatory=$true)] [string]$Name
    )

    # Lazy-load policy on first call
    if ($null -eq $script:BrPolicyData -and $global:DOTFILES_POLICY_FILE) {
        Backend-Registry-LoadPolicy
    }

    if ($null -ne $script:BrPolicyData) {
        $policy = $script:BrPolicyData

        if ($Kind -notin @("package", "runtime")) {
            Log-Error "Resolve-BackendFor: unsupported kind: $Kind"
            throw "Unsupported kind: $Kind"
        }

        # 1. Per-resource override (keyed by resource name, not feature name)
        if ($policy.PSObject.Properties[$Kind] -and
            $policy.$Kind.PSObject.Properties['overrides'] -and
            $policy.$Kind.overrides.PSObject.Properties[$Name] -and
            $policy.$Kind.overrides.$Name.PSObject.Properties['backend']) {
            return $policy.$Kind.overrides.$Name.backend
        }

        # 2. Kind-level default
        if ($policy.PSObject.Properties[$Kind] -and
            $policy.$Kind.PSObject.Properties['default_backend']) {
            return $policy.$Kind.default_backend
        }
    }

    return _Get-PlatformDefaultBackend -Kind $Kind
}

# _Get-PlatformDefaultBackend <Kind>
# Return the hardcoded platform default backend_id.
function _Get-PlatformDefaultBackend {
    param([string]$Kind)

    switch ($global:DOTFILES_PLATFORM) {
        { $_ -in @("linux", "wsl") } {
            switch ($Kind) {
                "package" { return "brew" }
                "runtime" { return "mise" }
                default { throw "Unsupported kind: $Kind" }
            }
        }
        "windows" {
            switch ($Kind) {
                "package" { return "scoop" }
                "runtime" { return "mise" }
                default { throw "Unsupported kind: $Kind" }
            }
        }
        default {
            throw "Unsupported platform: $($global:DOTFILES_PLATFORM)"
        }
    }
}

# ── Plugin loading ────────────────────────────────────────────────────────────

# Load-Backend <BackendId>
# Dot-source the backend plugin file and validate the Backend Plugin Contract.
function Load-Backend {
    param([Parameter(Mandatory=$true)] [string]$BackendId)

    if (-not $global:DOTFILES_BACKENDS_DIR) {
        Log-Error "Load-Backend: DOTFILES_BACKENDS_DIR is not set"
        throw "DOTFILES_BACKENDS_DIR is not set"
    }

    # Skip re-loading if same backend is already loaded
    if ($script:BrLoadedBackend -eq $BackendId) { return }

    $pluginFile = Join-Path $global:DOTFILES_BACKENDS_DIR "$BackendId.ps1"
    if (-not (Test-Path $pluginFile)) {
        Log-Error "Load-Backend: plugin not found: $pluginFile"
        throw "Backend plugin not found: $pluginFile"
    }

    . $pluginFile  # dot-source into current scope

    # Validate minimum contract
    if (-not (Get-Command "Backend-ApiVersion" -ErrorAction SilentlyContinue)) {
        $script:BrLoadedBackend = ""
        Log-Error "Load-Backend: contract violation: Backend-ApiVersion not defined (plugin: $pluginFile)"
        throw "Backend Plugin Contract violation"
    }

    $script:BrLoadedBackend = $BackendId
    Log-Info "Load-Backend: loaded backend plugin: $BackendId (api_version=$(Backend-ApiVersion))"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

# Backend-Call <Op> [Args...]
# Call an operation on the currently loaded backend plugin.
function Backend-Call {
    param(
        [Parameter(Mandatory=$true)] [string]$Op,
        [Parameter(ValueFromRemainingArguments=$true)] $Args
    )

    if (-not $script:BrLoadedBackend) {
        Log-Error "Backend-Call: no backend loaded; call Load-Backend first"
        throw "No backend loaded"
    }

    $func = "Backend-$($Op -replace '_', '-' | ForEach-Object { (Get-Culture).TextInfo.ToTitleCase($_) })"
    # Normalised: backend_install_package → Backend-InstallPackage
    $funcName = "Backend-" + (($Op -split '_') | ForEach-Object { (Get-Culture).TextInfo.ToTitleCase($_) }) -join ""

    if (-not (Get-Command $funcName -ErrorAction SilentlyContinue)) {
        Log-Error "Backend-Call: operation not defined: $funcName (loaded backend: $($script:BrLoadedBackend))"
        throw "Backend operation not defined: $funcName"
    }

    & $funcName @Args
}
