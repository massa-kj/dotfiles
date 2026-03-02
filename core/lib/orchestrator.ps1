# -----------------------------------------------------------------------------
# Module: orchestrator (PowerShell)
#
# Responsibility:
#   Orchestrate feature installation and uninstallation workflow.
#   Owns the full apply pipeline: profile read → diff → execute → summarise.
#
# Public API:
#   Invoke-OrchestratorApply <ProfileFile>   — run full apply pipeline
#
# Internal helpers (also usable by tests):
#   Read-Profile <ProfileFile>
#   Get-FeatureConfig <Feature>
#   Test-VersionMismatch <Feature>
#   Get-FeatureDiff <SortedFeatures>
#   Invoke-Uninstall <Features>
#   Invoke-Install <Features>
#   Show-Summary
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1, logger.ps1, and state.ps1 to be loaded by the caller.

# Lazily source resolver if not already loaded
if (-not (Get-Command Read-FeatureMetadata -ErrorAction SilentlyContinue)) {
    . "$env:DOTFILES_ROOT\core\lib\resolver.ps1"
}

# Lazily source backend_registry if not already loaded
if (-not (Get-Command Backend-Registry-LoadPolicy -ErrorAction SilentlyContinue)) {
    . "$env:DOTFILES_ROOT\core\lib\backend_registry.ps1"
}

# Lazily source planner if not already loaded
if (-not (Get-Command Invoke-PlannerRun -ErrorAction SilentlyContinue)) {
    . "$env:DOTFILES_ROOT\core\lib\planner.ps1"
}

# Lazily source executor if not already loaded
if (-not (Get-Command Invoke-ExecutorRun -ErrorAction SilentlyContinue)) {
    . "$env:DOTFILES_ROOT\core\lib\executor.ps1"
}

# Module-scoped profile cache
$script:ProfileData = ""

# ── Profile parsing ───────────────────────────────────────────────────────────

# Read-Profile <ProfileFile>
# Read profile YAML file and return list of feature names.
function Read-Profile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfileFile
    )

    if (-not (Test-Path $ProfileFile)) {
        Log-Error "Profile file not found: $ProfileFile"
        return $null
    }

    Log-Info "Reading profile..."

    try {
        $script:ProfileData = Get-Content $ProfileFile -Raw

        if (-not (Get-Command yq -ErrorAction SilentlyContinue)) {
            Log-Error "yq command not found. Please install yq."
            return $null
        }

        $features = & yq eval '.features | keys | .[]' $ProfileFile 2>$null
        $featureList = @()
        if ($LASTEXITCODE -eq 0 -and $features) {
            $featureList = @($features -split "`n" | Where-Object { $_ -ne "" })
        }

        if ($featureList.Count -eq 0) {
            Log-Warn "Empty profile (no features specified)"
            Log-Info "All installed features will be uninstalled"
            return @()
        }

        Log-Info "Desired features: $($featureList -join ' ')"
        return $featureList
    } catch {
        Log-Error "Failed to read profile: $_"
        return $null
    }
}

# Get-FeatureConfig <Feature>
# Extract configuration for a specific feature from cached profile data.
function Get-FeatureConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )

    if (-not $script:ProfileData) {
        return $null
    }

    try {
        $config = $script:ProfileData | & yq eval ".features.${Feature}" -o=json - 2>$null
        if ($LASTEXITCODE -eq 0 -and $config) {
            return ($config | ConvertFrom-Json)
        }
    } catch { }

    return $null
}

# ── Diff calculation ──────────────────────────────────────────────────────────

# Test-VersionMismatch <Feature>
# Return $true if desired version differs from installed, $false otherwise.
function Test-VersionMismatch {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )

    $featureConfig = Get-FeatureConfig -Feature $Feature
    $desiredVersion = $null
    if ($featureConfig -and ($null -ne $featureConfig.PSObject.Properties['version'])) {
        $desiredVersion = $featureConfig.version
    }

    if (-not $desiredVersion) { return $false }

    $installedVersion = State-GetRuntime -Feature $Feature -Key "version"
    if (-not $installedVersion) { return $true }

    return ($desiredVersion -ne $installedVersion)
}

# Get-FeatureDiff <SortedFeatures>
# Calculate install / uninstall / reinstall sets.
function Get-FeatureDiff {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$SortedFeatures
    )

    $installedFeatures = @(State-ListFeatures)
    $toInstall   = @()
    $toUninstall = @()
    $toReinstall = @()

    foreach ($feature in $SortedFeatures) {
        if (-not (State-HasFeature -Feature $feature)) {
            $toInstall += $feature
        } elseif (Test-VersionMismatch -Feature $feature) {
            Log-Info "Version mismatch detected for: $feature"
            $toReinstall += $feature
        }
    }

    foreach ($installed in $installedFeatures) {
        if ($installed -notin $SortedFeatures) {
            $toUninstall += $installed
        }
    }

    Log-Info "Features to install:   $(if ($toInstall.Count)   { $toInstall   -join ' ' } else { 'none' })"
    Log-Info "Features to uninstall: $(if ($toUninstall.Count) { $toUninstall -join ' ' } else { 'none' })"
    Log-Info "Features to reinstall: $(if ($toReinstall.Count) { $toReinstall -join ' ' } else { 'none' })"

    return @{
        ToInstall   = $toInstall
        ToUninstall = $toUninstall
        ToReinstall = $toReinstall
    }
}

# ── Execution ─────────────────────────────────────────────────────────────────

# Invoke-Uninstall <Features>
# Execute uninstall scripts in reverse dependency order.
function Invoke-Uninstall {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [string[]]$Features
    )

    if ($Features.Count -eq 0) { return $true }

    Log-Task "Uninstalling features..."

    # Process in reverse order
    for ($i = $Features.Count - 1; $i -ge 0; $i--) {
        $feature        = $Features[$i]
        $uninstallScript = Join-Path (Join-Path $env:DOTFILES_FEATURES_DIR $feature) "uninstall.ps1"

        if (-not (Test-Path $uninstallScript)) {
            Log-Error "Uninstall script not found: $uninstallScript"
            return $false
        }

        Log-Info "Uninstalling: $feature"
        try {
            & $uninstallScript
            if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
                throw "Script exited with code $LASTEXITCODE"
            }
        } catch {
            Log-Error "Failed to uninstall: $feature - $_"
            return $false
        }
    }

    return $true
}

# Invoke-Install <Features>
# Execute install scripts in dependency order.
function Invoke-Install {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [string[]]$Features
    )

    if ($Features.Count -eq 0) { return $true }

    Log-Task "Installing features..."

    foreach ($feature in $Features) {
        $installScript = Join-Path (Join-Path $env:DOTFILES_FEATURES_DIR $feature) "install.ps1"

        if (-not (Test-Path $installScript)) {
            Log-Error "Install script not found: $installScript"
            return $false
        }

        $featureConfig  = Get-FeatureConfig -Feature $feature
        $featureVersion = $null
        if ($featureConfig -and ($null -ne $featureConfig.PSObject.Properties['version'])) {
            $featureVersion = $featureConfig.version
        }

        Log-Info "Installing: $feature"

        if ($featureVersion) {
            $env:DOTFILES_FEATURE_CONFIG_VERSION = $featureVersion
        }

        try {
            & $installScript
            if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
                throw "Script exited with code $LASTEXITCODE"
            }
        } catch {
            Log-Error "Failed to install: $feature - $_"
            return $false
        } finally {
            Remove-Item Env:\DOTFILES_FEATURE_CONFIG_VERSION -ErrorAction SilentlyContinue
        }
    }

    return $true
}

# ── Summary ───────────────────────────────────────────────────────────────────

# Show-Summary
# Display installed features after a successful apply.
function Show-Summary {
    Write-Host ""
    Log-Success "Profile applied successfully!"
    Write-Host ""
    Write-Host "Installed features:"
    foreach ($feature in (State-ListFeatures)) {
        Write-Host "  ✓ $feature"
    }
    Write-Host ""
}

# ── Apply pipeline ────────────────────────────────────────────────────────────

# Invoke-OrchestratorApply <ProfileFile>
# Full apply pipeline. Entry point called by cmd/apply.ps1.
#
# Pipeline:
#   load policy → State-Init → Read-Profile → Resolve-Dependencies
#   → Invoke-PlannerRun → Invoke-ExecutorRun → Show-Summary
function Invoke-OrchestratorApply {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfileFile
    )

    if (-not (Test-Path $ProfileFile)) {
        Log-Error "Profile file not found: $ProfileFile"
        exit 1
    }

    # Load backend policy (non-fatal if policies dir is absent)
    Backend-Registry-LoadPolicy

    # Initialise (or migrate) state
    if (-not (State-Init)) {
        Log-Error "Failed to initialise state"
        exit 1
    }

    # Parse profile
    $desiredFeatures = Read-Profile -ProfileFile $ProfileFile
    if ($null -eq $desiredFeatures) { exit 1 }

    # Resolve feature metadata + topological sort
    if (-not (Read-FeatureMetadata -Features $desiredFeatures)) { exit 1 }

    $sortedFeatures = Resolve-Dependencies -DesiredFeatures $desiredFeatures
    if ($null -eq $sortedFeatures) { exit 1 }

    # Plan: pure computation of what needs to happen
    $planJson = Invoke-PlannerRun -ProfileFile $ProfileFile -SortedFeatures $sortedFeatures

    # Execute: impure — calls scripts, commits state
    Invoke-ExecutorRun -PlanJson $planJson

    Show-Summary
}
