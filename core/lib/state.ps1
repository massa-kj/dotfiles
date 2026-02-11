# State operation API

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Dependencies: ConvertFrom-Json, ConvertTo-Json, env.ps1, logger.ps1

function State-Init {
    <#
    .SYNOPSIS
    Initialize state file
    #>
    
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

function State-HasFeature {
    <#
    .SYNOPSIS
    Check if feature exists in state
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json
    return $null -ne $state.features.PSObject.Properties[$Feature]
}

function State-AddPackage {
    <#
    .SYNOPSIS
    Add package to feature
    #>
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

function State-AddFile {
    <#
    .SYNOPSIS
    Add file to feature
    #>
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

function State-GetPackages {
    <#
    .SYNOPSIS
    Get list of packages for feature
    #>
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

function State-GetFiles {
    <#
    .SYNOPSIS
    Get list of files for feature
    #>
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

function State-RemoveFeature {
    <#
    .SYNOPSIS
    Remove feature from state
    #>
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

function State-ListFeatures {
    <#
    .SYNOPSIS
    Get list of installed features
    #>
    
    if (-not (Test-Path $global:DOTFILES_STATE_FILE)) {
        return @()
    }

    $state = Get-Content -Path $global:DOTFILES_STATE_FILE -Raw | ConvertFrom-Json
    return $state.features.PSObject.Properties.Name
}

# Export functions
Export-ModuleMember -Function State-Init, State-HasFeature, State-AddPackage, State-AddFile, State-GetPackages, State-GetFiles, State-RemoveFeature, State-ListFeatures
