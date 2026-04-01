function Get-MinimumLogLevel {
    <#
    .SYNOPSIS
        Returns the configured minimum log level from the user's module configuration.
    .DESCRIPTION
        Reads the Logging.MinimumLogLevel property from Get-ModuleConfiguration.
        Returns 'Info' if the config is missing or the property is absent,
        which means all log entries are written (most verbose behaviour).

        Accepts an optional -ConfigPath parameter for testability. When provided, the configuration
        is loaded directly from that path instead of the default user configuration location.
    .PARAMETER ConfigPath
        Optional path to a configuration file for testing. If not provided, uses the default
        user configuration location via Get-ModuleConfiguration.
    .OUTPUTS
        string - One of 'Info', 'Warning', or 'Error'.
    #>
    [OutputType([string])]
    param(
        [string]$ConfigPath = $null
    )

    if ($ConfigPath) {
        # Test path: read directly from specified file
        if (-not (Test-Path $ConfigPath)) {
            return 'Info'
        }

        $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        if ($null -eq $json.Logging -or $null -eq $json.Logging.MinimumLogLevel) {
            return 'Info'
        }

        return $json.Logging.MinimumLogLevel
    }

    # Production path: use module configuration
    $config = Get-ModuleConfiguration

    if ($null -eq $config.Logging -or $null -eq $config.Logging.MinimumLogLevel) {
        return 'Info'
    }

    return $config.Logging.MinimumLogLevel
}

