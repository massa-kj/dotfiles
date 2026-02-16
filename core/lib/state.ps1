# -----------------------------------------------------------------------------
# Module: state
#
# Responsibility:
#   Manage state file operations safely with atomic updates.
#
# Public API (Stable):
#   State-Init
#   State-HasFeature <Feature>
#   State-AddPackage <Feature> <Package>
#   State-AddFile <Feature> <File>
#   State-GetPackages <Feature>
#   State-GetFiles <Feature>
#   State-RemoveFeature <Feature>
#   State-ListFeatures
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# State-Init
# Initialize or validate state file.
function State-Init {
    
    if (-not $global:DOTFILES_STATE_FILE) {
        Log-Error "DOTFILES_STATE_FILE is not set"
        return $false
    }

    # Create state directory if it doesn't exist
    $stateDir = Split-Path -Parent $global:DOTFILES_STATE_FILE
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    # Initialize state file if it doesn't exist
    if (-not (Test-Path $global:DOTFILES_STATE_FILE)) {
        $initialState = @{
            version = 1
            features = @{}
        }
        $initialState | ConvertTo-Json -Depth 10 | Set-Content -Path $global:DOTFILES_STATE_FILE -Encoding UTF8
    }

    # Validate JSON
    try {
        Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json | Out-Null
    } catch {
        Log-Error "state file is corrupted: $global:DOTFILES_STATE_FILE"
        return $false
    }

    return $true
}

# State-HasFeature <Feature>
# Check if a feature exists in state.
function State-HasFeature {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json
    return $null -ne $state.features.PSObject.Properties[$Feature]
}

# State-AddPackage <Feature> <Package>
# Register a package for a feature with deduplication.
function State-AddPackage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature,
        [Parameter(Mandatory=$true)]
        [string]$Package
    )

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json

    # Initialize feature if it doesn't exist
    if (-not $state.features.PSObject.Properties[$Feature]) {
        $state.features | Add-Member -MemberType NoteProperty -Name $Feature -Value @{
            packages = @()
            files = @()
        }
    }

    # Add package with deduplication
    $packages = $state.features.$Feature.packages
    if ($packages -notcontains $Package) {
        $state.features.$Feature.packages += $Package
    }

    # Save state
    try {
        $state | ConvertTo-Json -Depth 10 | Set-Content -Path $global:DOTFILES_STATE_FILE -Encoding UTF8
        return $true
    } catch {
        Log-Error "state_add_package: failed to add package - $_"
        return $false
    }
}

# State-AddFile <Feature> <File>
# Register a file path for a feature with deduplication.
function State-AddFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature,
        [Parameter(Mandatory=$true)]
        [string]$File
    )

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json

    # Initialize feature if it doesn't exist
    if (-not $state.features.PSObject.Properties[$Feature]) {
        $state.features | Add-Member -MemberType NoteProperty -Name $Feature -Value @{
            packages = @()
            files = @()
        }
    }

    # Add file with deduplication
    $files = $state.features.$Feature.files
    if ($files -notcontains $File) {
        $state.features.$Feature.files += $File
    }

    # Save state
    try {
        $state | ConvertTo-Json -Depth 10 | Set-Content -Path $global:DOTFILES_STATE_FILE -Encoding UTF8
        return $true
    } catch {
        Log-Error "state_add_file: failed to add file - $_"
        return $false
    }
}

# State-GetPackages <Feature>
# Retrieve package list for a feature.
function State-GetPackages {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )

    if (-not (State-HasFeature -Feature $Feature)) {
        return @()
    }

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json
    return $state.features.$Feature.packages
}

# State-GetFiles <Feature>
# Retrieve file path list for a feature.
function State-GetFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )

    if (-not (State-HasFeature -Feature $Feature)) {
        return @()
    }

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json
    return $state.features.$Feature.files
}

# State-RemoveFeature <Feature>
# Remove a feature entry from state.
function State-RemoveFeature {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )

    if (-not (State-HasFeature -Feature $Feature)) {
        Log-Warn "state_remove_feature: feature not found: $Feature"
        return $true
    }

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json
    $state.features.PSObject.Properties.Remove($Feature)

    # Save state
    try {
        $state | ConvertTo-Json -Depth 10 | Set-Content -Path $global:DOTFILES_STATE_FILE -Encoding UTF8
        return $true
    } catch {
        Log-Error "state_remove_feature: failed to remove feature - $_"
        return $false
    }
}

# State-ListFeatures
# Retrieve all installed feature names.
function State-ListFeatures {
    if (-not (Test-Path $global:DOTFILES_STATE_FILE)) {
        return @()
    }

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json
    return @($state.features.PSObject.Properties | ForEach-Object { $_.Name })
}
