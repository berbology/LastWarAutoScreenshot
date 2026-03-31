function Get-UploadProfile {
    <#
    .SYNOPSIS
        Reads one or all upload profiles from the profiles directory.

    .DESCRIPTION
        Without -Name: enumerates all *.json files in the profiles directory, parses each,
        populates missing optional fields with defaults, and returns an array. Returns an
        empty array when no profiles exist — never $null.

        With -Name: returns the single matching profile object, or $null if not found.

        Each returned object has all schema fields. Missing optional fields are populated
        with defaults so callers never need to null-check individual properties.

    .PARAMETER Name
        Optional. When specified, returns only the profile with this name.

    .PARAMETER ProfileDirectory
        Directory that contains the profile JSON files. Defaults to
        $env:APPDATA\LastWarAutoScreenshot\UploadProfiles.

    .OUTPUTS
        PSCustomObject or PSCustomObject[] or $null
        All-profiles call returns an array (possibly empty). Named call returns a single
        object or $null.

    .EXAMPLE
        $all = Get-UploadProfile

    .EXAMPLE
        $profile = Get-UploadProfile -Name 'azure-storage-1'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string]$ProfileDirectory = (Join-Path $env:APPDATA 'LastWarAutoScreenshot\UploadProfiles')
    )

    $defaults = @{
        provider              = 'AzureBlobStorage'
        cloudProvider         = 'azure'
        blobPathPattern       = '{MacroName}/{Date}/{Filename}'
        maxRetryAttempts      = 3
        retryBaseDelayMs      = 500
        deleteLocalAfterUpload = $false
        deleteLocalAfterDays  = 30
    }

    if (-not (Test-Path -LiteralPath $ProfileDirectory)) {
        if ($PSBoundParameters.ContainsKey('Name')) {
            return $null
        }
        return @()
    }

    $files = @(Get-ChildItem -Path $ProfileDirectory -Filter '*.json' -ErrorAction SilentlyContinue)

    $profiles = foreach ($file in $files) {
        $parsed = $null
        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
            $parsed  = $content | ConvertFrom-Json
        } catch {
            Write-LastWarLog -Level Error `
                -Message "Failed to parse upload profile JSON from '$($file.FullName)': $_" `
                -FunctionName 'Get-UploadProfile'
            continue
        }

        # Populate missing optional fields with defaults
        foreach ($key in $defaults.Keys) {
            if ($null -eq $parsed.PSObject.Properties[$key] -or $null -eq $parsed.$key) {
                $parsed | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key] -Force
            }
        }

        $parsed
    }

    if ($PSBoundParameters.ContainsKey('Name')) {
        $match = $profiles | Where-Object { $_.name -eq $Name } | Select-Object -First 1
        return $match
    }

    return @($profiles)
}
