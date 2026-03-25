function Get-LWASSASToken {
    <#
    .SYNOPSIS
        Returns all LWAS SAS tokens with validity information and optional online verification.

    .DESCRIPTION
        Scans the User and Process environment variable scopes for variables whose
        names begin with 'LWAS_SAS_' (case-insensitive). For each matching variable, returns a
        PSCustomObject containing the environment variable name, its current value, a Valid flag,
        and Validation/ValidationResponse properties that are always present on every returned
        object.

        A token is considered locally invalid if any of the following are true:
          - The environment variable value is null or an empty string
          - The token has no parseable expiry date (se= parameter)
          - The token's expiry is in the past or within the 5-minute safety buffer used by
            Test-LWASSASTokenIsValid

        When -VerifyOnline is not specified, Validation and ValidationResponse are $null.

        When -VerifyOnline is specified, tokens that pass all local validity checks are
        additionally tested by issuing an HTTP request against the associated Azure Blob
        Storage container endpoint, derived from an upload profile that references the
        token's environment variable name. Up to 3 attempts are made. If all attempts fail,
        a warning is written to the log via Write-LastWarLog.

        To retrieve only token names (equivalent to the old Get-LWASSASTokenEnvVarNames):

            Get-LWASSASToken | Select-Object -ExpandProperty Name

    .PARAMETER Name
        Optional. A name or wildcard pattern used to filter results. Only tokens whose
        environment variable name matches this pattern are returned. Matching is case-insensitive.
        Example: -Name 'LWAS_SAS_PROD*' returns only variables beginning with LWAS_SAS_PROD.

    .PARAMETER VerifyOnline
        When specified, tokens that pass local validity checks are also tested by issuing a
        live HTTP GET request to the associated Azure Blob Storage container endpoint (resolved
        from an upload profile whose sasTokenEnvVar matches the token's environment variable
        name). Up to 3 attempts are made before declaring failure.

        Validation is set to 'Pass', 'Fail', or 'Skip'. 'Skip' is used when the token fails
        local validity checks, or when no upload profile can be found that references the
        token's environment variable name (the endpoint URL cannot be determined without a
        storage account name). ValidationResponse is set to the HTTP status code string (e.g.
        '200', '403') on Pass or Fail, or 'N/A' on Skip. A warning is written to the module
        log when Validation is 'Fail'.

        When -VerifyOnline is not specified both Validation and ValidationResponse are $null.

    .PARAMETER Property
        Optional. A comma-separated list of property names to include in the returned objects.
        When specified, only the named properties are returned. Valid property names are:
        Name, Value, Valid, Validation, ValidationResponse.
        Example: -Property Name, Valid returns only the Name and Valid properties.

    .OUTPUTS
        PSCustomObject[]
        Each returned object always contains the following properties:
          Name               [string] — Environment variable name, e.g. 'LWAS_SAS_PROD'
          Value              [string] — Current environment variable value, or $null if unset
          Valid              [bool]   — $true when the token passes all local validity checks
          Validation         [string] — 'Pass', 'Fail', or 'Skip' when -VerifyOnline is used; $null otherwise
          ValidationResponse [string] — HTTP status code string or 'N/A' when -VerifyOnline is used; $null otherwise

    .EXAMPLE
        Get-LWASSASToken
        Returns all LWAS_SAS_* environment variables. Validation and ValidationResponse are $null.

    .EXAMPLE
        Get-LWASSASToken -Name 'LWAS_SAS_PROD*'
        Returns only tokens whose environment variable name begins with 'LWAS_SAS_PROD'.

    .EXAMPLE
        Get-LWASSASToken -VerifyOnline
        Returns all tokens with full online verification. Tokens that pass local checks are
        tested with up to 3 live HTTP requests against their associated Azure storage endpoint.
        Validation is 'Pass' or 'Fail' when verification was performed, 'Skip' otherwise.

    .EXAMPLE
        Get-LWASSASToken -Property Name, Valid
        Returns only the Name and Valid properties for all tokens.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [switch]$VerifyOnline,

        [Parameter()]
        [string[]]$Property
    )

    # Scan all env var scopes for LWAS_SAS_* names
    $scopes = @(
        [System.EnvironmentVariableTarget]::User,
        [System.EnvironmentVariableTarget]::Process
    )

    $allNames = foreach ($scope in $scopes) {
        $vars = [System.Environment]::GetEnvironmentVariables($scope)
        foreach ($key in $vars.Keys) {
            if ($key -imatch '^LWAS_SAS_') {
                $key
            }
        }
    }

    $uniqueNames = [string[]]@($allNames | Select-Object -Unique | Sort-Object)

    # Apply -Name wildcard filter when provided
    if (-not [string]::IsNullOrEmpty($Name)) {
        $uniqueNames = [string[]]@($uniqueNames | Where-Object { $_ -like $Name })
    }

    $results = foreach ($varName in $uniqueNames) {

        # Read value: process scope first (inherits user), then fall back explicitly
        $rawValue = [System.Environment]::GetEnvironmentVariable($varName)
        if ($null -eq $rawValue) {
            $rawValue = [System.Environment]::GetEnvironmentVariable($varName, [System.EnvironmentVariableTarget]::User)
        }
    

        # Coerce to empty string so Test-LWASSASTokenIsValid receives a valid [string] argument
        $varValue = if ($null -eq $rawValue) { '' } else { $rawValue }

        # Local validity: non-empty AND not expired (includes Test-LWASSASTokenIsValid's 5-min buffer)
        $localValid = -not [string]::IsNullOrEmpty($varValue) -and (Test-LWASSASTokenIsValid -SasToken $varValue)

        $validation         = $null
        $validationResponse = $null

        if ($VerifyOnline) {
            $validation         = 'Skip'
            $validationResponse = 'N/A'

            if ($localValid) {
                # Resolve the storage account and container from an associated upload profile
                $matchingProfile = @(Get-UploadProfile) |
                    Where-Object { $_.sasTokenEnvVar -eq $varName } |
                    Select-Object -First 1

                if ($null -ne $matchingProfile) {
                    $tokenQueryString = $varValue.TrimStart('?')
                    $testUri = "https://$($matchingProfile.accountName).blob.core.windows.net/$($matchingProfile.containerName)?restype=container&comp=list&$tokenQueryString"

                    $attempt        = 0
                    $succeeded      = $false
                    $lastStatusCode = 0

                    while ($attempt -lt 3 -and -not $succeeded) {
                        $attempt++
                        try {
                            $response       = Invoke-WebRequest -Uri $testUri -Method Get -UseBasicParsing -ErrorAction Stop
                            $lastStatusCode = [int]$response.StatusCode
                            $succeeded      = $true
                        } catch [Microsoft.PowerShell.Commands.HttpResponseException] {
                            $lastStatusCode = [int]$_.Exception.Response.StatusCode
                        } catch {
                            $lastStatusCode = 0
                        }
                    }

                    if ($succeeded) {
                        $validation         = 'Pass'
                        $validationResponse = "$lastStatusCode"
                    } else {
                        $validation         = 'Fail'
                        $validationResponse = "$lastStatusCode"
                        Write-LastWarLog `
                            -Message      "Online SAS token verification failed for '$varName' after $attempt attempt(s) (HTTP $lastStatusCode)." `
                            -Level        'Warning' `
                            -FunctionName 'Get-LWASSASToken' `
                            -Context      "EnvVar=$varName, Account=$($matchingProfile.accountName), Container=$($matchingProfile.containerName)"
                    }
                }
            }
        }

        [PSCustomObject]@{
            Name               = $varName
            Value              = $rawValue
            Valid              = $localValid
            Validation         = $validation
            ValidationResponse = $validationResponse
        }
    }

    if ($Property) {
        return [PSCustomObject[]]@($results | Select-Object -Property $Property)
    }

    return [PSCustomObject[]]@($results)
}
