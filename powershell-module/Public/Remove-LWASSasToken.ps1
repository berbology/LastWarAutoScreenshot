function Remove-LWASSasToken {
    <#
    .SYNOPSIS
        Removes a SAS token environment variable from User and Process scopes.

    .DESCRIPTION
        Deletes the specified environment variable from Windows User scope
        (HKCU:\Environment) and the current Process scope, whichever exist.
        After removal, the variable will not be available to new PowerShell sessions
        (User scope removed) or the current session (Process scope removed).

        An error is raised only if the variable is absent from both User and Process
        scope. Machine-scoped variables are not managed by this function.

        The variable name must consist of letters, digits, and underscores only.

    .PARAMETER Name
        Name of the environment variable to remove. Must consist of letters, digits,
        and underscores only (e.g. 'LWAS_SAS_PROD').

    .OUTPUTS
        None

    .EXAMPLE
        Remove-LWASSasToken -Name 'LWAS_SAS_PROD'

    .EXAMPLE
        Remove-LWASSasToken -Name 'LWAS_AZURE_SAS'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Name -match '[^A-Za-z0-9_]') {
        Write-Error "Name '$Name' contains invalid characters. Only letters, digits, and underscores are allowed."
        return
    }

    # Check existence in the two managed scopes (User and Process).
    # Machine scope is not managed by these functions and is intentionally excluded.
    $existsInUser    = $null -ne [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::User)
    $existsInProcess = $null -ne [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::Process)

    if (-not $existsInUser -and -not $existsInProcess) {
        throw "Environment variable '$Name' not found in User or Process scope."
    }

    # Remove from User scope (HKCU:\Environment registry) so new sessions no longer inherit the value.
    if ($existsInUser) {
        try {
            $regPath = 'HKCU:\Environment'
            if ((Get-Item -Path $regPath -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path $regPath -Name $Name -ErrorAction SilentlyContinue)) {
                Remove-ItemProperty -Path $regPath -Name $Name -ErrorAction Stop
            }
        } catch {
            throw "Failed to remove environment variable '$Name' from User registry: $_"
        }
    }

    # Remove from Process scope so the current session no longer sees the value.
    if ($existsInProcess) {
        [Environment]::SetEnvironmentVariable($Name, $null, [System.EnvironmentVariableTarget]::Process)
    }

    Write-Verbose "SAS token environment variable '$Name' has been removed."
}
