function Get-LWASSASTokenEnvVarNames {
    <#
    .SYNOPSIS
        Returns the names of all environment variables whose names begin with 'LWAS_SAS_'.

    .DESCRIPTION
        Scans the User, Machine, and Process environment variable scopes for variables
        whose names begin with 'LWAS_SAS_' (case-insensitive). Returns a deduplicated,
        alphabetically sorted array of matching names. Never returns $null; returns an
        empty array if no matches are found.

    .OUTPUTS
        System.String[]
        A (possibly empty) sorted array of unique environment variable names matching
        the 'LWAS_SAS_' prefix.

    .EXAMPLE
        $names = Get-LWASSASTokenEnvVarNames
        # Returns e.g. @('LWAS_SAS_PROD', 'LWAS_SAS_STAGING')
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $scopes = @(
        [System.EnvironmentVariableTarget]::User,
        [System.EnvironmentVariableTarget]::Machine,
        [System.EnvironmentVariableTarget]::Process
    )

    $names = foreach ($scope in $scopes) {
        $vars = [System.Environment]::GetEnvironmentVariables($scope)
        foreach ($key in $vars.Keys) {
            if ($key -imatch '^LWAS_SAS_') {
                $key
            }
        }
    }

    return [string[]]@($names | Select-Object -Unique | Sort-Object)
}
