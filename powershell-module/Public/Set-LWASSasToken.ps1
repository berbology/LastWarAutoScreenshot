function Set-LWASSasToken {
    <#
    .SYNOPSIS
        Persists a SAS token as a Windows User-scoped environment variable.

    .DESCRIPTION
        Saves the supplied SAS token under the given environment variable name at
        Windows User scope (HKCU:\Environment), so it survives PowerShell session
        restarts, and also applies it to the current Process scope so it is
        immediately available in the running session without a restart.

        The variable name must match the SasTokenEnvVar stored in the upload profile
        you want to use.

    .PARAMETER Name
        Name of the environment variable to set. Must consist of letters, digits,
        and underscores only (e.g. 'LWAS_AZURE_SAS').

    .PARAMETER Token
        The SAS token value to store. Can be empty to create a placeholder environment variable.

    .OUTPUTS
        None

    .EXAMPLE
        Set-LWASSasToken -Name 'LWAS_AZURE_SAS' -Token 'sv=2023-01-03&...'

    .EXAMPLE
        Set-LWASSasToken -Name 'LWAS_AZURE_SAS2' -Token $myToken
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Token
    )

    if ($Name -match '[^A-Za-z0-9_]') {
        Write-Error "Name '$Name' contains invalid characters. Only letters, digits, and underscores are allowed."
        return
    }

    # Persist at User scope so new sessions inherit the value automatically.
    Set-EnvironmentVariable -Name $Name -Value $Token -Target ([EnvironmentVariableTarget]::User)

    # Apply immediately to the current session so callers can use the value without restarting.
    Set-EnvironmentVariable -Name $Name -Value $Token -Target ([EnvironmentVariableTarget]::Process)

    Write-Verbose "SAS token saved to User environment variable '$Name'."
}
