function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        Loads a saved window target configuration from a file.

    .DESCRIPTION
        Reads and deserializes a window configuration from a JSON file that was previously
        saved using Save-ModuleConfiguration. Returns a configuration object containing
        ProcessName, WindowTitle, WindowHandle, and other window properties.

    .PARAMETER ConfigurationPath
        Optional path to the configuration file. If not specified, defaults to:
            $env:APPDATA\LastWarAutoScreenshot\WindowConfig.json

    .OUTPUTS
        PSCustomObject
        Returns configuration object with properties:
        - ProcessName (string): Name of the process
        - WindowTitle (string): Window title text
        - WindowHandleString (string): String representation of window handle
        - WindowHandleInt64 (int64): Numeric representation of window handle
        - ProcessID (uint32): Process identifier
        - WindowState (string): Window state at time of save
        - SavedDate (datetime): When configuration was saved
        - SavedBy (string): Username who saved the configuration
        - ComputerName (string): Computer name where configuration was saved

    .EXAMPLE
        $config = Get-ModuleConfiguration
        Write-Host "Loaded configuration for: $($config.ProcessName) - $($config.WindowTitle)"
        
        Loads window configuration from the default location.

    .EXAMPLE
        $config = Get-ModuleConfiguration -ConfigurationPath "C:\Config\MyWindow.json"
        
        Loads window configuration from a custom path.

    .NOTES
        - Configuration file must be in JSON format as created by Save-ModuleConfiguration
        - Returns $null if configuration file does not exist
        - WindowHandle values are stored as string and int64 for cross-session compatibility
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath
    )

    begin {
        Write-Verbose "Starting window configuration load process"
        # Import Write-LastWarLog for logging
        . "$PSScriptRoot/Write-LastWarLog.ps1"
        
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
        try {
            # Check if configuration file exists
            if (-not (Test-Path -Path $ConfigurationPath -PathType Leaf)) {
                Write-Verbose "Configuration file not found at: $ConfigurationPath"
                Write-Warning "Warning: No saved window configuration found at: $ConfigurationPath"
                Write-LastWarLog -Message "No saved window configuration found at: $ConfigurationPath" -Level Warning -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath"
                return $null
            }

            Write-Verbose "Reading configuration file: $ConfigurationPath"
            
            # Read file content
            $jsonContent = Get-Content -Path $ConfigurationPath -Raw -ErrorAction Stop
            
            if ([string]::IsNullOrWhiteSpace($jsonContent)) {
                Write-Error "Error: Configuration file is empty: $ConfigurationPath"
                Write-LastWarLog -Message "Configuration file is empty: $ConfigurationPath" -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
                return $null
            }

            Write-Verbose "Deserializing JSON content"
            
            # Deserialize JSON to object
            $configData = $jsonContent | ConvertFrom-Json -ErrorAction Stop

            # MouseControl config defaults
            $mouseDefaults = @{
                EasingEnabled = $true
                OvershootEnabled = $true
                OvershootFactor = 0.1
                MicroPausesEnabled = $true
                MicroPauseChance = 0.2
                MicroPauseDurationRangeMs = @(20, 80)
                JitterEnabled = $true
                JitterRadiusPx = 2
                BezierControlPointOffsetFactor = 0.3
                MovementDurationRangeMs = @(200, 600)
            }
            if (-not $configData.PSObject.Properties['MouseControl']) {
                $configData | Add-Member -MemberType NoteProperty -Name MouseControl -Value ([PSCustomObject]$mouseDefaults)
            }

            # Validate required properties exist
            $requiredProperties = @('ProcessName', 'WindowTitle', 'WindowHandleString', 'WindowHandleInt64')
            $missingProperties = $requiredProperties | Where-Object { -not $configData.PSObject.Properties[$_] }

            if ($missingProperties.Count -gt 0) {
                $errorMsg = "Configuration file is missing required properties: $($missingProperties -join ', ')"
                Write-Error "Error: $errorMsg"
                Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
                throw $errorMsg
            }

            Write-Verbose "Configuration loaded successfully: ProcessName=$($configData.ProcessName), WindowTitle=$($configData.WindowTitle)"
            Write-Host "Loaded window configuration: $($configData.ProcessName) - $($configData.WindowTitle)" -ForegroundColor Green

            # Return configuration object
            return $configData
        }
        catch [System.IO.IOException] {
            $errorMsg = "Failed to read configuration file: $_"
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
            throw
        }
        catch [System.ArgumentException] {
            $errorMsg = "Invalid JSON format in configuration file: $_"
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
            throw
        }
        catch {
            $errorMsg = "Unexpected error loading window configuration: $_"
            Write-Error "Error: $errorMsg"
            Write-LastWarLog -Message $errorMsg -Level Error -FunctionName 'Get-ModuleConfiguration' -Context "Path: $ConfigurationPath" -LogStackTrace $_
            throw
        }
    }

    end {
        Write-Verbose "Window configuration load process completed"
    }
}
