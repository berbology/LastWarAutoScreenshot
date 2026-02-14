function Test-ModuleConfigurationExists {
    <#
    .SYNOPSIS
        Checks if a window configuration file exists.

    .DESCRIPTION
        Tests for the presence of a saved window configuration file at the specified or
        default location. Returns $true if the file exists, $false otherwise.

    .PARAMETER ConfigurationPath
        Optional path to the configuration file. If not specified, checks the default location:
            $env:APPDATA\LastWarAutoScreenshot\WindowConfig.json

    .OUTPUTS
        System.Boolean
        Returns $true if configuration file exists, $false otherwise.

    .EXAMPLE
        if (Test-ModuleConfigurationExists) {
            Write-Host "Configuration file found"
        }
        
        Checks if a configuration file exists at the default location.

    .EXAMPLE
        Test-ModuleConfigurationExists -ConfigurationPath "C:\Config\MyWindow.json"
        
        Checks if a configuration file exists at a custom path.

    .NOTES
        - This is a simple wrapper around Test-Path for consistency with other configuration functions
        - Returns $false if the path exists but is a directory rather than a file
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath
    )

    begin {
        Write-Verbose "Checking for window configuration file"
        
        # Set default configuration path if not specified
        if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
            $defaultConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'LastWarAutoScreenshot'
            $ConfigurationPath = Join-Path -Path $defaultConfigDir -ChildPath 'WindowConfig.json'
            Write-Verbose "Using default configuration path: $ConfigurationPath"
        }
        else {
            Write-Verbose "Using custom configuration path: $ConfigurationPath"
        }
    }

    process {
        # Test if path exists and is a file (not a directory)
        $exists = Test-Path -Path $ConfigurationPath -PathType Leaf
        
        Write-Verbose "Configuration file exists: $exists"
        
        return $exists
    }

    end {
        Write-Verbose "Configuration existence check completed"
    }
}
