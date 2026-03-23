function Set-LWASSasToken {
    <#
    .SYNOPSIS
        Persists a SAS token as a Windows User-scoped environment variable.

    .DESCRIPTION
        Saves the supplied SAS token under the given environment variable name at
        Windows User scope (HKCU:\Environment), so it survives PowerShell session
        restarts. The token is also applied to the current Process scope immediately,
        meaning it is available to uploads without restarting the session.

        The variable name must match the SasTokenEnvVar stored in the upload profile
        you want to use.

    .PARAMETER EnvVarName
        Name of the environment variable to set. Must consist of letters, digits,
        and underscores only (e.g. 'LWAS_AZURE_SAS').

    .PARAMETER Token
        The SAS token value to store. Must not be empty.

    .OUTPUTS
        None

    .EXAMPLE
        Set-LWASSasToken -EnvVarName 'LWAS_AZURE_SAS' -Token 'sv=2023-01-03&...'

    .EXAMPLE
        Set-LWASSasToken -EnvVarName 'LWAS_AZURE_SAS2' -Token $myToken
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvVarName,

        [Parameter(Mandatory)]
        [string]$Token
    )

    if ($EnvVarName -match '[^A-Za-z0-9_]') {
        Write-Error "EnvVarName '$EnvVarName' contains invalid characters. Only letters, digits, and underscores are allowed."
        return
    }

    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Error 'Token must not be empty.'
        return
    }

    # Persist at User scope so new sessions inherit the value automatically.
    [Environment]::SetEnvironmentVariable($EnvVarName, $Token, [EnvironmentVariableTarget]::User)

    # Also apply to the current process so uploads work immediately without reopening PowerShell.
    [Environment]::SetEnvironmentVariable($EnvVarName, $Token, [EnvironmentVariableTarget]::Process)

    Write-Verbose "SAS token saved to User environment variable '$EnvVarName'."
}
