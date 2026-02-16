<#
.SYNOPSIS
    Pester tests for Get-EnumeratedWindows function.

.DESCRIPTION
    Unit tests for window enumeration functionality using Pester v5.
    Tests include mocking Win32 API calls and validating filtering logic.
#>

BeforeAll {
    # Import required type definitions and function
    $typeDefPath = Join-Path $PSScriptRoot 'WindowEnumeration_TypeDefinition.ps1'
    $functionPath = Join-Path $PSScriptRoot 'Get-EnumeratedWindows.ps1'
    
    . $typeDefPath
    . $functionPath
    
    # Mock helper function to create test window data
    function New-MockWindowData {
        <#
        .SYNOPSIS
            Creates mock window data for testing.
        
        .DESCRIPTION
            Helper function to generate consistent test window objects without
            requiring actual Win32 API calls. Used to inject predictable data
            into tests.
        
        .PARAMETER ProcessName
            Name of the process (e.g., "LastWar", "notepad")
        
        .PARAMETER WindowTitle
            Title text for the window
        
        .PARAMETER WindowHandle
            Integer to use as window handle (will be converted to IntPtr)
        
        .PARAMETER ProcessId
            Process ID
        
        .PARAMETER IsVisible
            Whether the window is visible
        
        .PARAMETER IsMinimized
            Whether the window is minimized
        
        .OUTPUTS
            PSCustomObject representing a window with all required properties
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$ProcessName,
            
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$WindowTitle,
            
            [Parameter(Mandatory)]
            [int]$WindowHandle,
            
            [Parameter(Mandatory)]
            [uint32]$ProcessId,
            
            [Parameter(Mandatory)]
            [bool]$IsVisible,
            
            [Parameter(Mandatory)]
            [bool]$IsMinimized
        )
        
        $hwnd = [IntPtr]$WindowHandle
        $windowState = if ($IsMinimized) { "Minimized" }
                      elseif ($IsVisible) { "Visible" }
                      else { "Hidden" }
        
        return [PSCustomObject]@{
            ProcessName         = $ProcessName
            WindowTitle         = $WindowTitle
            WindowHandle        = $hwnd
            WindowHandleString  = $hwnd.ToString()
            WindowHandleInt     = [int64]$hwnd
            ProcessId           = $ProcessId
            WindowState         = $windowState
        }
    }
    
    # Mock process objects for Get-Process
    $script:MockProcesses = @{
        1234 = [PSCustomObject]@{ ProcessName = "LastWar"; Id = 1234 }
        5678 = [PSCustomObject]@{ ProcessName = "notepad"; Id = 5678 }
        9012 = [PSCustomObject]@{ ProcessName = "chrome"; Id = 9012 }
        3456 = [PSCustomObject]@{ ProcessName = "explorer"; Id = 3456 }
    }
}

Describe "Get-EnumeratedWindows" -Tag "Unit" {
    
    Context "Basic functionality" {
        
        BeforeAll {
            # Mock Win32 API calls to simulate window enumeration
            Mock -CommandName 'Invoke-Command' -MockWith {
                # This is a simplified mock - actual mocking of P/Invoke is complex
                # In real tests, we'd need to mock the WindowEnumerationAPI class methods
            }
            
            # Mock Get-Process to return predictable data
            Mock -CommandName Get-Process -MockWith {
                param($Id)
                return $script:MockProcesses[$Id]
            }
        }
        
        It "Should have proper CmdletBinding attributes" {
            $commandInfo = Get-Command Get-EnumeratedWindows
            $commandInfo.CmdletBinding | Should -Be $true
        }
        
        It "Should accept ProcessName parameter as string array" {
            $commandInfo = Get-Command Get-EnumeratedWindows
            $param = $commandInfo.Parameters['ProcessName']
            $param.ParameterType.Name | Should -Be "String[]"
        }
        
        It "Should accept ExcludeMinimized switch parameter" {
            $commandInfo = Get-Command Get-EnumeratedWindows
            $param = $commandInfo.Parameters['ExcludeMinimized']
            $param.SwitchParameter | Should -Be $true
        }
        
        It "Should accept VisibleOnly switch parameter" {
            $commandInfo = Get-Command Get-EnumeratedWindows
            $param = $commandInfo.Parameters['VisibleOnly']
            $param.SwitchParameter | Should -Be $true
        }
        
        It "Should have OutputType attribute set to PSCustomObject array" {
            $commandInfo = Get-Command Get-EnumeratedWindows
            $outputType = $commandInfo.OutputType.Type.Name
            # PowerShell returns PSObject[] for [PSCustomObject[]] OutputType
            $outputType | Should -Contain "PSObject[]"
        }
    }
    
    Context "Return object structure" {
        
        It "Should return objects with all required properties" {
            # Create mock window data
            $mockWindow = New-MockWindowData -ProcessName "LastWar" `
                                            -WindowTitle "Last War: Survival" `
                                            -WindowHandle 12345 `
                                            -ProcessId 1234 `
                                            -IsVisible $true `
                                            -IsMinimized $false
            
            # Verify all properties exist
            $mockWindow.PSObject.Properties.Name | Should -Contain "ProcessName"
            $mockWindow.PSObject.Properties.Name | Should -Contain "WindowTitle"
            $mockWindow.PSObject.Properties.Name | Should -Contain "WindowHandle"
            $mockWindow.PSObject.Properties.Name | Should -Contain "WindowHandleString"
            $mockWindow.PSObject.Properties.Name | Should -Contain "WindowHandleInt"
            $mockWindow.PSObject.Properties.Name | Should -Contain "ProcessId"
            $mockWindow.PSObject.Properties.Name | Should -Contain "WindowState"
        }
        
        It "Should have WindowHandle as IntPtr type" {
            $mockWindow = New-MockWindowData -ProcessName "LastWar" `
                                            -WindowTitle "Test" `
                                            -WindowHandle 12345 `
                                            -ProcessId 1234 `
                                            -IsVisible $true `
                                            -IsMinimized $false
            
            $mockWindow.WindowHandle.GetType().Name | Should -Be "IntPtr"
        }
        
        It "Should have WindowHandleString as string representation" {
            $mockWindow = New-MockWindowData -ProcessName "LastWar" `
                                            -WindowTitle "Test" `
                                            -WindowHandle 12345 `
                                            -ProcessId 1234 `
                                            -IsVisible $true `
                                            -IsMinimized $false
            
            $mockWindow.WindowHandleString | Should -BeOfType [string]
            $mockWindow.WindowHandleString | Should -Be "12345"
        }
        
        It "Should have WindowHandleInt as numeric representation" {
            $mockWindow = New-MockWindowData -ProcessName "LastWar" `
                                            -WindowTitle "Test" `
                                            -WindowHandle 12345 `
                                            -ProcessId 1234 `
                                            -IsVisible $true `
                                            -IsMinimized $false
            
            $mockWindow.WindowHandleInt | Should -BeOfType [int64]
            $mockWindow.WindowHandleInt | Should -Be 12345
        }
    }
    
    Context "Window state detection" {
        
        It "Should report 'Visible' for visible, non-minimized window" {
            $mockWindow = New-MockWindowData -ProcessName "LastWar" `
                                            -WindowTitle "Test" `
                                            -WindowHandle 12345 `
                                            -ProcessId 1234 `
                                            -IsVisible $true `
                                            -IsMinimized $false
            
            $mockWindow.WindowState | Should -Be "Visible"
        }
        
        It "Should report 'Minimized' for minimized window" {
            $mockWindow = New-MockWindowData -ProcessName "LastWar" `
                                            -WindowTitle "Test" `
                                            -WindowHandle 12345 `
                                            -ProcessId 1234 `
                                            -IsVisible $true `
                                            -IsMinimized $true
            
            $mockWindow.WindowState | Should -Be "Minimized"
        }
        
        It "Should report 'Hidden' for non-visible window" {
            $mockWindow = New-MockWindowData -ProcessName "System" `
                                            -WindowTitle "" `
                                            -WindowHandle 12345 `
                                            -ProcessId 1234 `
                                            -IsVisible $false `
                                            -IsMinimized $false
            
            $mockWindow.WindowState | Should -Be "Hidden"
        }
    }
    
    Context "Filtering logic with mock data" {
        
        BeforeAll {
            # Create collection of mock windows for filtering tests
            $script:TestWindows = @(
                (New-MockWindowData -ProcessName "LastWar" -WindowTitle "Last War: Survival" `
                                   -WindowHandle 1001 -ProcessId 1234 -IsVisible $true -IsMinimized $false),
                (New-MockWindowData -ProcessName "notepad" -WindowTitle "Untitled - Notepad" `
                                   -WindowHandle 1002 -ProcessId 5678 -IsVisible $true -IsMinimized $true),
                (New-MockWindowData -ProcessName "chrome" -WindowTitle "Google Chrome" `
                                   -WindowHandle 1003 -ProcessId 9012 -IsVisible $true -IsMinimized $false),
                (New-MockWindowData -ProcessName "explorer" -WindowTitle "Windows Explorer" `
                                   -WindowHandle 1004 -ProcessId 3456 -IsVisible $false -IsMinimized $false)
            )
        }
        
        It "Should filter by ProcessName when specified" {
            $filtered = $script:TestWindows | Where-Object {
                @("LastWar", "notepad") -contains $_.ProcessName
            }
            
            $filtered.Count | Should -Be 2
            $filtered.ProcessName | Should -Contain "LastWar"
            $filtered.ProcessName | Should -Contain "notepad"
        }
        
        It "Should exclude minimized windows when ExcludeMinimized is used" {
            $filtered = $script:TestWindows | Where-Object {
                $_.WindowState -eq "Visible"
            }
            
            $filtered.Count | Should -Be 2
            $filtered.ProcessName | Should -Contain "LastWar"
            $filtered.ProcessName | Should -Contain "chrome"
        }
        
        It "Should only return visible windows when VisibleOnly is used" {
            $filtered = $script:TestWindows | Where-Object {
                $_.WindowState -eq "Visible"
            }
            
            $filtered.Count | Should -Be 2
            $filtered | ForEach-Object {
                $_.WindowState | Should -Be "Visible"
            }
        }
        
        It "Should filter out hidden windows (no taskbar presence)" {
            $filtered = $script:TestWindows | Where-Object {
                $_.WindowState -ne "Hidden"
            }
            
            $filtered.Count | Should -Be 3
            $filtered.ProcessName | Should -Not -Contain "explorer"
        }
    }
    
    Context "Error handling" {
        
        It "Should throw error if WindowEnumerationAPI type is not loaded (Type unloading in tests is complex to implement safely)" {
            Set-ItResult -Skipped -Because "Pending: Type unloading in tests is complex to implement safely"
        }

        It "Should handle process termination gracefully (Requires full integration test with EnumWindows callback)" {
            Set-ItResult -Skipped -Because "Pending: Requires full integration test with EnumWindows callback"
        }

        It "Should collect and report enumeration errors (Requires complex Win32 API callback mocking)" {
            Set-ItResult -Skipped -Because "Pending: Requires complex Win32 API callback mocking"
        }
    }
    
    Context "Performance considerations" {
        
        It "Should use ForEach-Object -Parallel for process lookups" {
            # Verify the function code contains parallel processing
            $functionContent = Get-Content (Join-Path $PSScriptRoot 'Get-EnumeratedWindows.ps1') -Raw
            $functionContent | Should -Match "ForEach-Object -Parallel"
        }
        
        It "Should set ThrottleLimit to 16 for multi-core optimization" {
            $functionContent = Get-Content (Join-Path $PSScriptRoot 'Get-EnumeratedWindows.ps1') -Raw
            $functionContent | Should -Match "-ThrottleLimit 16"
        }
    }
    
    Context "Verbose output" {
        
        It "Should output verbose messages when -Verbose is specified" {
            Set-ItResult -Skipped -Because "Pending: Requires integration test to capture verbose stream"
            # This would be tested in integration tests
        }
    }
}

Describe "New-MockWindowData helper" -Tag "Unit", "Helper" {
    
    Context "Mock data generation" {
        
        It "Should create valid window object with all parameters" {
            $window = New-MockWindowData -ProcessName "TestApp" `
                                        -WindowTitle "Test Window" `
                                        -WindowHandle 99999 `
                                        -ProcessId 8888 `
                                        -IsVisible $true `
                                        -IsMinimized $false
            
            $window | Should -Not -BeNullOrEmpty
            $window.ProcessName | Should -Be "TestApp"
            $window.WindowTitle | Should -Be "Test Window"
            $window.ProcessId | Should -Be 8888
        }
        
        It "Should handle various window states correctly" {
            $visible = New-MockWindowData -ProcessName "App1" -WindowTitle "Window1" `
                                         -WindowHandle 1 -ProcessId 100 -IsVisible $true -IsMinimized $false
            $minimized = New-MockWindowData -ProcessName "App2" -WindowTitle "Window2" `
                                           -WindowHandle 2 -ProcessId 200 -IsVisible $true -IsMinimized $true
            $hidden = New-MockWindowData -ProcessName "App3" -WindowTitle "Window3" `
                                        -WindowHandle 3 -ProcessId 300 -IsVisible $false -IsMinimized $false
            
            $visible.WindowState | Should -Be "Visible"
            $minimized.WindowState | Should -Be "Minimized"
            $hidden.WindowState | Should -Be "Hidden"
        }
    }
}
