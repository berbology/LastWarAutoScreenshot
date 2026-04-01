function Get-LoggingBackendConfig {
    <#
    .SYNOPSIS
        Loads the logging backend configuration from the user's module configuration.
    .DESCRIPTION
        Reads the Logging.Backend property from Get-ModuleConfiguration and returns an array
        of backend names (e.g., File, EventLog).

        Accepts an optional -ConfigPath parameter for testability. When provided, the configuration
        is loaded directly from that path instead of the default user configuration location.
    .PARAMETER ConfigPath
        Optional path to a configuration file for testing. If not provided, uses the default
        user configuration location via Get-ModuleConfiguration.
    .OUTPUTS
        string[]
    #>
    [OutputType([string[]])]
    param(
        [string]$ConfigPath = $null
    )

    if ($ConfigPath) {
        # Test path: read directly from specified file
        if (-not (Test-Path $ConfigPath)) {
            return @('File') # Default to file backend if config missing
        }
        $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        if ($null -eq $json.Logging -or $null -eq $json.Logging.Backend) {
            return @('File')
        }
        return $json.Logging.Backend -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    # Production path: use module configuration
    $config = Get-ModuleConfiguration
    if ($null -eq $config.Logging -or $null -eq $config.Logging.Backend) {
        return @('File')
    }
    return $config.Logging.Backend -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

