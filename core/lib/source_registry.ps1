# -----------------------------------------------------------------------------
# Module: source_registry
#
# Responsibility:
#   Canonical ID utilities for feature and backend identification.
#   A canonical ID is a string of the form "<source_id>/<name>".
#
#   This module provides Phase 1 foundations only.
#   Source loading (sources.yaml, allow lists) is Phase 5.
#
# Reserved source IDs (may not be defined in sources.yaml):
#   core     -- built-in features shipped with this repository
#   user     -- local user overrides
#   official -- reserved for future use
#
# Public API (Stable):
#   Canonical-Id-Normalize <Name> <DefaultSourceId>
#   Canonical-Id-Parse     <CanonicalId>
#   Canonical-Id-Validate  <CanonicalId>
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects logger.ps1 to be loaded by the caller.

# List of source IDs that cannot be defined by the user in sources.yaml.
$script:CanonicalIdReservedSources = @("core", "user", "official")

# Canonical-Id-Normalize <Name> <DefaultSourceId>
#
# Normalize a feature/backend name to a canonical ID.
# If <Name> is already a canonical ID ("source/name"), it is returned as-is.
# If <Name> is a bare name, "<DefaultSourceId>/<Name>" is produced.
#
# Returns the canonical ID string.
# Throws if the resulting canonical ID would be invalid.
#
# Examples:
#   Canonical-Id-Normalize "git"         "core"   -> "core/git"
#   Canonical-Id-Normalize "user/myfeat" "core"   -> "user/myfeat"
#   Canonical-Id-Normalize "repo-a/foo"  "core"   -> "repo-a/foo"
function Canonical-Id-Normalize {
    param(
        [string]$Name,
        [string]$DefaultSourceId
    )

    if ([string]::IsNullOrEmpty($Name)) {
        throw "Canonical-Id-Normalize: Name is required"
    }
    if ([string]::IsNullOrEmpty($DefaultSourceId)) {
        throw "Canonical-Id-Normalize: DefaultSourceId is required"
    }

    $result = if ($Name -match '/') {
        # Already contains a slash — treat as canonical
        $Name
    } else {
        # Bare name — prepend default source
        "${DefaultSourceId}/${Name}"
    }

    if (-not (Canonical-Id-Validate $result)) {
        throw "Canonical-Id-Normalize: resulting ID is invalid: '$result'"
    }

    return $result
}

# Canonical-Id-Parse <CanonicalId>
#
# Parse a canonical ID and return a hashtable with keys SourceId and Name.
# Throws if <CanonicalId> is not a valid canonical ID.
#
# Example:
#   $parts = Canonical-Id-Parse "core/git"
#   $parts.SourceId  # "core"
#   $parts.Name      # "git"
function Canonical-Id-Parse {
    param([string]$CanonicalId)

    if (-not (Canonical-Id-Validate $CanonicalId)) {
        throw "Canonical-Id-Parse: invalid canonical ID: '$CanonicalId'"
    }

    $slashIndex = $CanonicalId.IndexOf('/')
    return @{
        SourceId = $CanonicalId.Substring(0, $slashIndex)
        Name     = $CanonicalId.Substring($slashIndex + 1)
    }
}

# Canonical-Id-Validate <CanonicalId>
#
# Return $true if <CanonicalId> is a well-formed canonical ID, $false otherwise.
# A valid canonical ID:
#   - is non-empty
#   - contains exactly one "/" separator
#   - has a non-empty source_id part (left of "/")
#   - has a non-empty name part (right of "/")
#   - neither part contains a "/"
#
# Does NOT check whether the source_id is reserved — that is the caller's responsibility.
function Canonical-Id-Validate {
    param([string]$CanonicalId)

    if ([string]::IsNullOrEmpty($CanonicalId)) {
        return $false
    }

    # Must contain exactly one "/"
    $slashCount = ($CanonicalId.ToCharArray() | Where-Object { $_ -eq '/' }).Count
    if ($slashCount -ne 1) {
        return $false
    }

    $slashIndex = $CanonicalId.IndexOf('/')
    $sourcePart = $CanonicalId.Substring(0, $slashIndex)
    $namePart   = $CanonicalId.Substring($slashIndex + 1)

    if ([string]::IsNullOrEmpty($sourcePart) -or [string]::IsNullOrEmpty($namePart)) {
        return $false
    }

    return $true
}
