    Context 'Logging integration' {
        BeforeEach {
            Mock -CommandName Write-LastWarLog -MockWith {}
        }

        It 'Should log error when no windows found after filtering' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith { return @() }
            Select-TargetWindowFromMenu -ProcessName 'none' | Out-Null
            Should -Invoke Write-LastWarLog -ParameterFilter {
                $Level -eq 'Error' -and $FunctionName -eq 'Select-TargetWindowFromMenu'
            } -Exactly 1
        }

        It 'Should log error when selected window closed before action' {
            $mockWindows = @(New-MockWindowData)
            Mock -CommandName 'Test-WindowExists' -MockWith { return $false }
            $script:closedCallCount = 0
            Mock -CommandName 'Get-UserSelection' -MockWith {
                $script:closedCallCount++
                if ($script:closedCallCount -eq 1) { @{ Command = 'Select'; Value = 1 } }
                else { @{ Command = 'Exit'; Value = $null } }
            }
            Mock -CommandName 'Show-Menu' -MockWith {}
            Mock -CommandName 'Get-SortedWindows' -MockWith { $mockWindows }
            Show-MenuLoop -Windows $mockWindows | Out-Null
            Should -Invoke Write-LastWarLog -ParameterFilter {
                $Level -eq 'Error' -and $FunctionName -eq 'Show-MenuLoop' -and $Message -like '*closed before action*'
            }
        }

        It 'Should log warning for invalid selection' {
            $mockWindows = @(New-MockWindowData)
            $script:invalidCallCount = 0
            Mock -CommandName 'Get-UserSelection' -MockWith {
                $script:invalidCallCount++
                if ($script:invalidCallCount -eq 1) { @{ Command = 'Select'; Value = 99 } }
                else { @{ Command = 'Exit'; Value = $null } }
            }
            Mock -CommandName 'Show-Menu' -MockWith {}
            Mock -CommandName 'Get-SortedWindows' -MockWith { $mockWindows }
            Show-MenuLoop -Windows $mockWindows | Out-Null
            Should -Invoke Write-LastWarLog -ParameterFilter {
                $Level -eq 'Warning' -and $FunctionName -eq 'Show-MenuLoop' -and $Message -like '*Invalid selection*'
            }
        }

        It 'Should log info when user cancels selection' {
            $mockWindows = @(New-MockWindowData)
            Mock -CommandName 'Get-UserSelection' -MockWith { @{ Command = 'Exit'; Value = $null } }
            Mock -CommandName 'Show-Menu' -MockWith {}
            Mock -CommandName 'Get-SortedWindows' -MockWith { $mockWindows }
            Show-MenuLoop -Windows $mockWindows | Out-Null
            Should -Invoke Write-LastWarLog -ParameterFilter {
                $Level -eq 'Info' -and $FunctionName -eq 'Show-MenuLoop' -and $Message -like '*cancelled*'
            }
        }

        It 'Should log warning when no windows found after refresh' {
            $mockWindows = @(New-MockWindowData)
            $script:refreshCallCount = 0
            Mock -CommandName 'Get-UserSelection' -MockWith {
                $script:refreshCallCount++
                if ($script:refreshCallCount -eq 1) { @{ Command = 'Refresh'; Value = $null } }
                else { @{ Command = 'Exit'; Value = $null } }
            }
            Mock -CommandName 'Show-Menu' -MockWith {}
            Mock -CommandName 'Get-SortedWindows' -MockWith { $mockWindows }
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith { return @() }
            Show-MenuLoop -Windows $mockWindows | Out-Null
            Should -Invoke Write-LastWarLog -ParameterFilter {
                $Level -eq 'Warning' -and $FunctionName -eq 'Show-MenuLoop' -and $Message -like '*after refresh*'
            }
        }

        It 'Should log info when refresh attempted on piped input' {
            $mockWindows = @(New-MockWindowData)
            $script:refreshPipeCallCount = 0
            Mock -CommandName 'Get-UserSelection' -MockWith {
                $script:refreshPipeCallCount++
                if ($script:refreshPipeCallCount -eq 1) { @{ Command = 'Refresh'; Value = $null } }
                else { @{ Command = 'Exit'; Value = $null } }
            }
            Mock -CommandName 'Show-Menu' -MockWith {}
            Mock -CommandName 'Get-SortedWindows' -MockWith { $mockWindows }
            $script:useInternalEnumeration = $false
            Show-MenuLoop -Windows $mockWindows | Out-Null
            Should -Invoke Write-LastWarLog -ParameterFilter {
                $Level -eq 'Info' -and $FunctionName -eq 'Show-MenuLoop' -and $Message -like '*Cannot refresh piped input*'
            }
        }
    }
BeforeAll {
    # Import the function under test
    . $PSScriptRoot/Select-TargetWindowFromMenu.ps1
    . $PSScriptRoot/Get-EnumeratedWindows.ps1
    . $PSScriptRoot/WindowEnumeration_TypeDefinition.ps1
    
    # Helper function to create mock window data
    function New-MockWindowData {
        param(
            [string]$ProcessName = 'TestProcess',
            [string]$WindowTitle = 'Test Window',
            [int64]$WindowHandle = 123456789,
            [int]$ProcessID = 1000,
            [string]$WindowState = 'Visible'
        )
        
        return [PSCustomObject]@{
            ProcessName = $ProcessName
            WindowTitle = $WindowTitle
            WindowHandle = [IntPtr]$WindowHandle
            WindowHandleString = $WindowHandle.ToString()
            WindowHandleInt64 = $WindowHandle
            ProcessID = $ProcessID
            WindowState = $WindowState
        }
    }
}

Describe 'Select-TargetWindowFromMenu' {
    Context 'When accepting pipeline input' {
        BeforeAll {
            $mockWindows = @(
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Google Chrome' -WindowHandle 111
                New-MockWindowData -ProcessName 'notepad' -WindowTitle 'Untitled - Notepad' -WindowHandle 222
                New-MockWindowData -ProcessName 'LastWar' -WindowTitle 'Last War Game' -WindowHandle 333
            )
        }
        
        It 'Should accept window objects from pipeline' {
            # Mock user selecting first window (input: 1, Enter)
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return $mockWindows[0]
            } -ModuleName $null
            
            $result = $mockWindows | Select-TargetWindowFromMenu
            
            $result | Should -Not -BeNullOrEmpty
            $result.ProcessName | Should -Be 'chrome'
        }
        
        It 'Should handle empty pipeline input gracefully' {
            $result = @() | Select-TargetWindowFromMenu
            
            $result | Should -BeNullOrEmpty
        }
        
        It 'Should preserve all window properties from pipeline' {
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return $mockWindows[2]
            } -ModuleName $null
            
            $result = $mockWindows | Select-TargetWindowFromMenu
            
            $result.ProcessName | Should -Be 'LastWar'
            $result.WindowTitle | Should -Be 'Last War Game'
            $result.WindowHandle | Should -Be 333
            $result.ProcessID | Should -Be 1000
            $result.WindowState | Should -Be 'Visible'
        }
    }
    
    Context 'When using internal enumeration' {
        BeforeAll {
            $mockWindows = @(
                New-MockWindowData -ProcessName 'LastWar' -WindowTitle 'Last War Game' -WindowHandle 444
            )
        }
        
        It 'Should call Get-EnumeratedWindows when no pipeline input provided' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                return $mockWindows
            }
            
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return $mockWindows[0]
            } -ModuleName $null
            
            $result = Select-TargetWindowFromMenu
            
            Should -Invoke Get-EnumeratedWindows -Exactly 1
        }
        
        It 'Should pass ProcessName parameter to Get-EnumeratedWindows' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                param($ProcessName)
                $ProcessName | Should -Be 'LastWar'
                return $mockWindows
            }
            
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return $mockWindows[0]
            } -ModuleName $null
            
            $result = Select-TargetWindowFromMenu -ProcessName 'LastWar'
            
            Should -Invoke Get-EnumeratedWindows -Exactly 1
        }
        
        It 'Should pass ExcludeMinimized parameter to Get-EnumeratedWindows' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                param($ExcludeMinimized)
                $ExcludeMinimized | Should -Be $true
                return $mockWindows
            }
            
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return $mockWindows[0]
            } -ModuleName $null
            
            $result = Select-TargetWindowFromMenu -ExcludeMinimized
            
            Should -Invoke Get-EnumeratedWindows -Exactly 1
        }
        
        It 'Should pass VisibleOnly parameter to Get-EnumeratedWindows' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                param($VisibleOnly)
                $VisibleOnly | Should -Be $true
                return $mockWindows
            }
            
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return $mockWindows[0]
            } -ModuleName $null
            
            $result = Select-TargetWindowFromMenu -VisibleOnly
            
            Should -Invoke Get-EnumeratedWindows -Exactly 1
        }
    }
    
    Context 'When no windows are found' {
        It 'Should return null when enumeration returns no windows' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                return @()
            }
            
            $result = Select-TargetWindowFromMenu
            
            $result | Should -BeNullOrEmpty
        }
        
        It 'Should display informative message when no windows found' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                return @()
            }
            
            Mock -CommandName 'Write-Information' -MockWith {}
            
            $result = Select-TargetWindowFromMenu
            
            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -match 'No windows found'
            }
        }
    }
    
    Context 'When user cancels selection' {
        BeforeAll {
            $mockWindows = @(
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Google Chrome' -WindowHandle 555
            )
        }
        
        It 'Should return null when user exits' {
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return $null
            } -ModuleName $null
            
            $result = $mockWindows | Select-TargetWindowFromMenu
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context 'Parameter validation' {
        It 'Should accept valid SortBy values' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                return @(New-MockWindowData)
            }
            
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return New-MockWindowData
            } -ModuleName $null
            
            { Select-TargetWindowFromMenu -SortBy 'ProcessName' } | Should -Not -Throw
            { Select-TargetWindowFromMenu -SortBy 'WindowTitle' } | Should -Not -Throw
            { Select-TargetWindowFromMenu -SortBy 'WindowState' } | Should -Not -Throw
        }
        
        It 'Should reject invalid SortBy values' {
            { Select-TargetWindowFromMenu -SortBy 'InvalidSort' } | Should -Throw
        }
        
        It 'Should accept DetailedView switch' {
            Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                return @(New-MockWindowData)
            }
            
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return New-MockWindowData
            } -ModuleName $null
            
            { Select-TargetWindowFromMenu -DetailedView } | Should -Not -Throw
        }
    }
}

Describe 'Get-SortedWindows' {
    BeforeAll {
        # Create function in module scope for testing
        . $PSScriptRoot/Select-TargetWindowFromMenu.ps1
        
        $script:windows = @(
            New-MockWindowData -ProcessName 'zebra' -WindowTitle 'ABC Window' -WindowState 'Visible'
            New-MockWindowData -ProcessName 'alpha' -WindowTitle 'XYZ Window' -WindowState 'Minimized'
            New-MockWindowData -ProcessName 'beta' -WindowTitle 'MNO Window' -WindowState 'Visible'
        )
    }
    
    Context 'When sorting by ProcessName' {
        It 'Should sort ascending by ProcessName' {
            $script:currentSort = 'ProcessName'
            $script:sortAscending = $true
            $result = Get-SortedWindows -Windows $script:windows
            $result[0].ProcessName | Should -Be 'alpha'
            $result[1].ProcessName | Should -Be 'beta'
            $result[2].ProcessName | Should -Be 'zebra'
        }
        It 'Should sort descending by ProcessName' {
            $script:currentSort = 'ProcessName'
            $script:sortAscending = $false
            $result = Get-SortedWindows -Windows $script:windows
            $result[0].ProcessName | Should -Be 'zebra'
            $result[1].ProcessName | Should -Be 'beta'
            $result[2].ProcessName | Should -Be 'alpha'
        }
    }
    
    Context 'When sorting by WindowTitle' {
        It 'Should sort ascending by WindowTitle' {
            $script:currentSort = 'WindowTitle'
            $script:sortAscending = $true
            $result = Get-SortedWindows -Windows $script:windows
            $result[0].WindowTitle | Should -Be 'ABC Window'
            $result[1].WindowTitle | Should -Be 'MNO Window'
            $result[2].WindowTitle | Should -Be 'XYZ Window'
        }
        It 'Should sort descending by WindowTitle' {
            $script:currentSort = 'WindowTitle'
            $script:sortAscending = $false
            $result = Get-SortedWindows -Windows $script:windows
            $result[0].WindowTitle | Should -Be 'XYZ Window'
            $result[1].WindowTitle | Should -Be 'MNO Window'
            $result[2].WindowTitle | Should -Be 'ABC Window'
        }
    }
    
    Context 'When sorting by WindowState' {
        It 'Should sort ascending by WindowState' {
            $script:currentSort = 'WindowState'
            $script:sortAscending = $true
            $result = Get-SortedWindows -Windows $script:windows
            $result[0].WindowState | Should -Be 'Minimized'
            $result[2].WindowState | Should -Be 'Visible'
        }
        It 'Should sort descending by WindowState' {
            $script:currentSort = 'WindowState'
            $script:sortAscending = $false
            $result = Get-SortedWindows -Windows $script:windows
            $result[0].WindowState | Should -Be 'Visible'
        }
    }
}

Describe 'Test-WindowExists' {
    BeforeAll {
        . $PSScriptRoot/Select-TargetWindowFromMenu.ps1
    }

    Context 'When validating window handles' {
        It 'Should return true for valid window handle' {
            Mock -CommandName 'Get-WindowTextLength' -MockWith {
                return 10  # Simulate valid window handle
            }

            $handle = [IntPtr]123456
            $result = Test-WindowExists -WindowHandle $handle

            $result | Should -Be $true
        }

        It 'Should return false when window handle is invalid' {
            Mock -CommandName 'Get-WindowTextLength' -MockWith {
                return 0  # Simulate invalid window handle
            }

            $handle = [IntPtr]0
            $result = Test-WindowExists -WindowHandle $handle

            $result | Should -Be $false
        }
    }
}

Describe 'Integration tests' {
    Context 'When multiple windows with same process name exist' {
        BeforeAll {
            $mockWindows = @(
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Tab 1' -WindowHandle 111
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Tab 2' -WindowHandle 222
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Tab 3' -WindowHandle 333
            )
        }
        
        It 'Should allow selection of specific window by index' {
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                return $mockWindows[1]  # Select second chrome window
            } -ModuleName $null
            
            $result = $mockWindows | Select-TargetWindowFromMenu
            
            $result.WindowTitle | Should -Be 'Tab 2'
            $result.WindowHandle | Should -Be 222
        }
    }
    
    Context 'When windows contain minimized applications' {
        BeforeAll {
            $mockWindows = @(
                New-MockWindowData -ProcessName 'notepad' -WindowTitle 'Notepad' -WindowState 'Visible'
                New-MockWindowData -ProcessName 'calc' -WindowTitle 'Calculator' -WindowState 'Minimized'
            )
        }
        
        It 'Should display both visible and minimized windows' {
            $localMockWindows = @(
                New-MockWindowData -ProcessName 'notepad' -WindowTitle 'Notepad' -WindowState 'Visible'
                New-MockWindowData -ProcessName 'calc' -WindowTitle 'Calculator' -WindowState 'Minimized'
            )
            Mock -CommandName 'Show-MenuLoop' -MockWith {
                param($Windows)
                $Windows.Count | Should -Be 2
                return $localMockWindows[0]
            } -ModuleName $null
            $result = Select-TargetWindowFromMenu -WindowList $localMockWindows
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
