function Set-EnvironmentVariable {
    <#
    .SYNOPSIS
        Thin wrapper around [Environment]::SetEnvironmentVariable to allow mocking in tests.

    .PARAMETER Name
        The environment variable name.

    .PARAMETER Value
        The value to assign.

    .PARAMETER Target
        The scope: Process, User, or Machine.

    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [System.EnvironmentVariableTarget]$Target
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, $Target)
}
