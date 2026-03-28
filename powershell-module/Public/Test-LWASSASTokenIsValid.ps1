function Test-LWASSASTokenIsValid {
    <#
    .SYNOPSIS
        Tests whether a SAS token string is currently valid.

    .DESCRIPTION
        Parses the signed expiry parameter (se=) from the SAS token query string and
        compares it to the current UTC time with a 5-minute safety buffer.

        Returns $false if the token is null, empty, missing an se= parameter, has an
        unparseable expiry value, or will expire within 5 minutes. Returns $true otherwise.

        This is a pure string operation — no network calls and no Az module required.
        Signature validity and permission scope are not checked.

    .PARAMETER SasToken
        The SAS token query string to validate. May optionally begin with a leading '?'.
        Accepts empty strings.

    .OUTPUTS
        [bool]
        $true when the token is present and will remain valid for at least 5 minutes.
        $false in all other cases.

    .EXAMPLE
        Test-LWASSASTokenIsValid -SasToken $env:LWAS_SAS_PROD

    .EXAMPLE
        if (-not (Test-LWASSASTokenIsValid -SasToken $env:LWAS_SAS_PROD)) {
            Update-LWASSASToken -UploadProfile $uploadProfile
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$SasToken
    )

    if ([string]::IsNullOrWhiteSpace($SasToken)) {
        return $false
    }

    # Strip a leading '?' if present (Az module sometimes includes it)
    $queryString = $SasToken.TrimStart('?')

    # Parse key=value pairs; split on first '=' only to preserve encoded values
    $pairs = $queryString -split '&'
    $seValue = $null
    foreach ($pair in $pairs) {
        $eqIndex = $pair.IndexOf('=')
        if ($eqIndex -le 0) {
            continue
        }
        $key = $pair.Substring(0, $eqIndex)
        if ($key -ieq 'se') {
            $seValue = $pair.Substring($eqIndex + 1)
            break
        }
    }

    if ($null -eq $seValue) {
        return $false
    }

    # URL-decode the value; Az module encodes colons as %3A (e.g. 2026-04-02T22%3A22%3A43Z)
    $seValue = [System.Uri]::UnescapeDataString($seValue)

    # Attempt to parse the expiry as UTC datetime
    $expiryUtc  = [datetime]::MinValue
    $parsed     = $false
    $invariant  = [System.Globalization.CultureInfo]::InvariantCulture
    $utcStyles  = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor `
                  [System.Globalization.DateTimeStyles]::AdjustToUniversal

    $parsed = [datetime]::TryParseExact(
        $seValue,
        'yyyy-MM-ddTHH:mm:ssZ',
        $invariant,
        $utcStyles,
        [ref]$expiryUtc
    )

    if (-not $parsed) {
        # Fall back to general parsing
        try {
            $expiryUtc = [datetime]::Parse($seValue, $invariant,
                [System.Globalization.DateTimeStyles]::AdjustToUniversal)
            $parsed = $true
        } catch {
            return $false
        }
    }

    # Apply 5-minute safety buffer
    $minutesRemaining = ($expiryUtc - [datetime]::UtcNow).TotalMinutes
    return $minutesRemaining -ge 5
}
