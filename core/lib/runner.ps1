# Command helpers and utilities

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects logger.ps1 to be loaded by the caller.

function Test-Command {
    <#
    .SYNOPSIS
    Check if a command exists in PATH
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Assert-Command {
    <#
    .SYNOPSIS
    Require that a command exists, exit if not found
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    if (-not (Test-Command -Command $Command)) {
        Log-Error "Required command not found: $Command"
        throw "Required command not found: $Command"
    }
}

function Invoke-OrDie {
    <#
    .SYNOPSIS
    Run command and exit on failure
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        [string]$Description
    )
    
    if ($Description) {
        Log-Info "Running: $Description"
    }
    
    try {
        & $ScriptBlock
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Command failed with exit code $LASTEXITCODE"
        }
    } catch {
        Log-Error "Command failed: $_"
        throw
    }
}

function Test-Administrator {
    <#
    .SYNOPSIS
    Check if running as Administrator
    #>
    
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
    <#
    .SYNOPSIS
    Require administrator privileges
    #>
    
    if (-not (Test-Administrator)) {
        Log-Error "This operation requires Administrator privileges"
        Log-Info "Please restart PowerShell as Administrator"
        throw "Administrator privileges required"
    }
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
    Execute command with retry logic
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2
    )
    
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            & $ScriptBlock
            return $true
        } catch {
            if ($attempt -eq $MaxAttempts) {
                Log-Error "Failed after $MaxAttempts attempts: $_"
                throw
            }
            
            Log-Warn "Attempt $attempt failed, retrying in ${DelaySeconds}s..."
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

function Get-UserConfirmation {
    <#
    .SYNOPSIS
    Ask user for yes/no confirmation
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [bool]$DefaultYes = $false
    )
    
    $prompt = if ($DefaultYes) { "$Message [Y/n]" } else { "$Message [y/N]" }
    Write-Host $prompt -NoNewline
    
    $response = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }
    
    return $response -match '^[Yy]'
}

# Export functions
Export-ModuleMember -Function Test-Command, Assert-Command, Invoke-OrDie, Test-Administrator, Assert-Administrator, Invoke-WithRetry, Get-UserConfirmation
