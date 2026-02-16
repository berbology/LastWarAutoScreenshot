function Get-LoggingBackendConfig {
    <#
    .SYNOPSIS
        Loads the logging backend configuration from ModuleConfig.json.
    .DESCRIPTION
        Reads the Logging.Backend property from the config file and returns an array of backend names (e.g., File, EventLog).
    .OUTPUTS
        string[]
    #>
    [OutputType([string[]])]
    param()
    $configPath = Join-Path $PSScriptRoot 'ModuleConfig.json'
    if (-not (Test-Path $configPath)) {
        return @('File') # Default to file backend if config missing
    }
    $json = Get-Content $configPath -Raw | ConvertFrom-Json
    if ($null -eq $json.Logging -or $null -eq $json.Logging.Backend) {
        return @('File')
    }
    return $json.Logging.Backend -split ',' | ForEach-Object { $_.Trim() }
}
