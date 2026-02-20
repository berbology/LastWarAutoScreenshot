function Get-LoggingBackendConfig {
    <#
    .SYNOPSIS
        Loads the logging backend configuration from ModuleConfig.json or a specified path.
    .DESCRIPTION
        Reads the Logging.Backend property from the config file and returns an array of backend names (e.g., File, EventLog).
        Accepts an optional -ConfigPath parameter for testability.
    .OUTPUTS
        string[]
    #>
    [OutputType([string[]])]
    param(
        [string]$ConfigPath = $(Join-Path $PSScriptRoot 'ModuleConfig.json')
    )
    if (-not (Test-Path $ConfigPath)) {
        return @('File') # Default to file backend if config missing
    }
    $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($null -eq $json.Logging -or $null -eq $json.Logging.Backend) {
        return @('File')
    }
    return $json.Logging.Backend -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}
