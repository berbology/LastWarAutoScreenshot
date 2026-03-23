function Get-MinimumLogLevel {
    <#
    .SYNOPSIS
        Returns the configured minimum log level from ModuleConfig.jsonc.
    .DESCRIPTION
        Reads the Logging.MinimumLogLevel property from the config file.
        Returns 'Info' if the config is missing or the property is absent,
        which means all log entries are written (most verbose behaviour).
        Accepts an optional -ConfigPath parameter for testability.
    .PARAMETER ConfigPath
        Path to the JSONC config file. Defaults to the ModuleConfig.jsonc in the Private directory.
    .OUTPUTS
        string - One of 'Info', 'Warning', or 'Error'.
    #>
    [OutputType([string])]
    param(
        [string]$ConfigPath = $(Join-Path $PSScriptRoot 'ModuleConfig.jsonc')
    )

    if (-not (Test-Path $ConfigPath)) {
        return 'Info'
    }

    $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    if ($null -eq $json.Logging -or $null -eq $json.Logging.MinimumLogLevel) {
        return 'Info'
    }

    return $json.Logging.MinimumLogLevel
}

