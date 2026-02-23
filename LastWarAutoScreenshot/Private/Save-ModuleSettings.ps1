function Save-ModuleSettings {
    <#
    .SYNOPSIS
        Persists a module configuration object to disk without requiring a window target.

    .DESCRIPTION
        Serialises the supplied configuration object to JSON and writes it to the module
        configuration file.  Unlike Save-ModuleConfiguration, this function does not
        require a window target (ProcessName, WindowHandle, etc.) to be present, making
        it suitable for use by the configuration screens that only modify settings sections
        (Logging, MouseControl, EmergencyStop) without touching the window target.

        If the config object contains window-target properties they are preserved (because
        the caller passes the full config returned by Get-ModuleConfiguration).

        The parent directory is created if it does not already exist.

    .PARAMETER Config
        The full configuration object to persist.  Typically obtained by calling
        Get-ModuleConfiguration, modifying the relevant section, and then passing the
        updated object here.

    .PARAMETER ConfigurationPath
        Optional path to the configuration file.  Defaults to the same path used by
        Get-ModuleConfiguration:
            $env:APPDATA\LastWarAutoScreenshot\WindowConfig.json

    .OUTPUTS
        Boolean
        Returns $true on success; throws on failure.

    .EXAMPLE
        $config = Get-ModuleConfiguration
        $config.Logging.MinimumLogLevel = 'Warning'
        Save-ModuleSettings -Config $config

    .EXAMPLE
        # Reset all logging keys to defaults, then save.
        $config = Get-ModuleConfiguration
        $defaults = Get-DefaultModuleSettings
        $config.Logging = $defaults.Logging
        Save-ModuleSettings -Config $config

    .NOTES
        This function is the settings-only counterpart to Save-ModuleConfiguration.
        Use Save-ModuleConfiguration when saving a newly selected window target.
        Use Save-ModuleSettings when only module settings (Logging, MouseControl,
        EmergencyStop) have changed and the window target is unmodified.

        Depth 5 is used for serialisation to handle the three-level nesting of
        FileBackend keys (e.g. Logging.FileBackend.MaxSizeMB).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath
    )

    begin {
        Write-Verbose 'Starting module settings save'

        if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
            $defaultConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshot'
            $ConfigurationPath = Join-Path -Path $defaultConfigDir -ChildPath 'WindowConfig.json'
            Write-Verbose "Using default configuration path: $ConfigurationPath"
        }
    }

    process {
        try {
            $parentDir = Split-Path -Path $ConfigurationPath -Parent
            if ($parentDir -and -not (Test-Path -Path $parentDir -PathType Container)) {
                New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "Created configuration directory: $parentDir"
            }

            $Config | ConvertTo-Json -Depth 5 |
                Set-Content -Path $ConfigurationPath -Encoding UTF8 -Force -ErrorAction Stop

            Write-LastWarLog -Level Info `
                -Message "Module settings saved to: $ConfigurationPath" `
                -FunctionName 'Save-ModuleSettings'
            Write-Verbose "Module settings saved to: $ConfigurationPath"

            return $true
        }
        catch [System.IO.IOException] {
            $errorMsg = "Failed to write module settings file: $_"
            Write-LastWarLog -Level Error -Message $errorMsg -FunctionName 'Save-ModuleSettings'
            throw
        }
        catch [System.UnauthorizedAccessException] {
            $errorMsg = "Access denied writing module settings to '$ConfigurationPath'. Check permissions."
            Write-LastWarLog -Level Error -Message $errorMsg -FunctionName 'Save-ModuleSettings'
            throw
        }
        catch {
            $errorMsg = "Unexpected error saving module settings: $_"
            Write-LastWarLog -Level Error -Message $errorMsg -FunctionName 'Save-ModuleSettings'
            throw
        }
    }
}

