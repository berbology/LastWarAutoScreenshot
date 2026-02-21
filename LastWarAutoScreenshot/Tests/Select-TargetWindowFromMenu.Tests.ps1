BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
    function New-MockWindowData {
        param(
            [string]$ProcessName = 'TestProcess',
            [string]$WindowTitle = 'Test Window',
            [int64]$WindowHandle = 123456789,
            [int]$ProcessID = 1000,
            [string]$WindowState = 'Visible'
        )
        return [PSCustomObject]@{
            ProcessName        = $ProcessName
            WindowTitle        = $WindowTitle
            WindowHandle       = [IntPtr]$WindowHandle
            WindowHandleString = $WindowHandle.ToString()
            WindowHandleInt64  = $WindowHandle
            ProcessID          = $ProcessID
            WindowState        = $WindowState
        }
    }
}

Describe 'Show-MenuLoop logging' -Tag 'Unit' {
    Context 'Logging integration' {
        It 'Should log error when no windows found after filtering' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName Write-LastWarLog -MockWith {}
                Mock -CommandName 'Get-EnumeratedWindows' -MockWith { return @() }
                Select-TargetWindowFromMenu -ProcessName 'none' | Out-Null
                Should -Invoke Write-LastWarLog -ParameterFilter {
                    $Level -eq 'Error' -and $FunctionName -eq 'Select-TargetWindowFromMenu'
                } -Exactly 1
            }
        }

        It 'Should log error when selected window closed before action' {
            $mockWindowsOuter = @(New-MockWindowData)
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindows = $mockWindowsOuter } {
                Mock -CommandName Write-LastWarLog -MockWith {}
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
        }

        It 'Should log warning for invalid selection' {
            $mockWindowsOuter = @(New-MockWindowData)
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindows = $mockWindowsOuter } {
                Mock -CommandName Write-LastWarLog -MockWith {}
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
        }

        It 'Should log info when user cancels selection' {
            $mockWindowsOuter = @(New-MockWindowData)
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindows = $mockWindowsOuter } {
                Mock -CommandName Write-LastWarLog -MockWith {}
                Mock -CommandName 'Get-UserSelection' -MockWith { @{ Command = 'Exit'; Value = $null } }
                Mock -CommandName 'Show-Menu' -MockWith {}
                Mock -CommandName 'Get-SortedWindows' -MockWith { $mockWindows }
                Show-MenuLoop -Windows $mockWindows | Out-Null
                Should -Invoke Write-LastWarLog -ParameterFilter {
                    $Level -eq 'Info' -and $FunctionName -eq 'Show-MenuLoop' -and $Message -like '*cancelled*'
                }
            }
        }

        It 'Should log warning when no windows found after refresh' {
            $mockWindowsOuter = @(New-MockWindowData)
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindows = $mockWindowsOuter } {
                Mock -CommandName Write-LastWarLog -MockWith {}
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
        }

        It 'Should log info when refresh attempted on piped input' {
            $mockWindowsOuter = @(New-MockWindowData)
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindows = $mockWindowsOuter } {
                Mock -CommandName Write-LastWarLog -MockWith {}
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
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindows = $mockWindows } {
                # Mock user selecting first window (input: 1, Enter)
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return $mockWindows[0]
                }
                $result = $mockWindows | Select-TargetWindowFromMenu
                $result | Should -Not -BeNullOrEmpty
                $result.ProcessName | Should -Be 'chrome'
            }
        }
        
        It 'Should handle empty pipeline input gracefully' {
            InModuleScope LastWarAutoScreenshot {
                $result = @() | Select-TargetWindowFromMenu
                $result | Should -BeNullOrEmpty
            }
        }
        
        It 'Should preserve all window properties from pipeline' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindows = $mockWindows } {
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return $mockWindows[2]
                }
                $result = $mockWindows | Select-TargetWindowFromMenu
                $result.ProcessName | Should -Be 'LastWar'
                $result.WindowTitle | Should -Be 'Last War Game'
                $result.WindowHandle | Should -Be 333
                $result.ProcessID | Should -Be 1000
                $result.WindowState | Should -Be 'Visible'
            }
        }
    }
    
    Context 'When using internal enumeration' {
        BeforeAll {
            $mockWindows = @(
                New-MockWindowData -ProcessName 'LastWar' -WindowTitle 'Last War Game' -WindowHandle 444
            )
        }
        
        It 'Should call Get-EnumeratedWindows when no pipeline input provided' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                    return $mockWindows
                }
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return $mockWindows[0]
                }
                $result = Select-TargetWindowFromMenu
                Should -Invoke Get-EnumeratedWindows -Exactly 1
            }
        }
        
        It 'Should pass ProcessName parameter to Get-EnumeratedWindows' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                    param($ProcessName)
                    $ProcessName | Should -Be 'LastWar'
                    return $mockWindows
                }
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return $mockWindows[0]
                }
                $result = Select-TargetWindowFromMenu -ProcessName 'LastWar'
                Should -Invoke Get-EnumeratedWindows -Exactly 1
            }
        }
        
        It 'Should pass ExcludeMinimized parameter to Get-EnumeratedWindows' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                    param($ExcludeMinimized)
                    $ExcludeMinimized | Should -Be $true
                    return $mockWindows
                }
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return $mockWindows[0]
                }
                $result = Select-TargetWindowFromMenu -ExcludeMinimized
                Should -Invoke Get-EnumeratedWindows -Exactly 1
            }
        }
        
        It 'Should pass VisibleOnly parameter to Get-EnumeratedWindows' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                    param($VisibleOnly)
                    $VisibleOnly | Should -Be $true
                    return $mockWindows
                }
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return $mockWindows[0]
                }
                $result = Select-TargetWindowFromMenu -VisibleOnly
                Should -Invoke Get-EnumeratedWindows -Exactly 1
            }
        }
    }
    
    Context 'When no windows are found' {
        It 'Should return null when enumeration returns no windows' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                    return @()
                }
                $result = Select-TargetWindowFromMenu
                $result | Should -BeNullOrEmpty
            }
        }
        
        It 'Should display informative message when no windows found' {
            InModuleScope LastWarAutoScreenshot {
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
    }
    
    Context 'When user cancels selection' {
        BeforeAll {
            $mockWindows = @(
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Google Chrome' -WindowHandle 555
            )
        }
        
        It 'Should return null when user exits' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return $null
                }
                $result = $mockWindows | Select-TargetWindowFromMenu
                $result | Should -BeNullOrEmpty
            }
        }
    }
    
    Context 'Parameter validation' {
        It 'Should accept valid SortBy value: <SortBy>' -TestCases @(
            @{ SortBy = 'ProcessName' }
            @{ SortBy = 'WindowTitle' }
            @{ SortBy = 'WindowState' }
        ) {
            InModuleScope LastWarAutoScreenshot -Parameters @{ SortBy = $SortBy } {
                Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                    return @([PSCustomObject]@{
                        ProcessName        = 'TestProcess'
                        WindowTitle        = 'Test Window'
                        WindowHandle       = [IntPtr]123456789
                        WindowHandleString = '123456789'
                        WindowHandleInt64  = [int64]123456789
                        ProcessID          = 1000
                        WindowState        = 'Visible'
                    })
                }
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return [PSCustomObject]@{
                        ProcessName        = 'TestProcess'
                        WindowTitle        = 'Test Window'
                        WindowHandle       = [IntPtr]123456789
                        WindowHandleString = '123456789'
                        WindowHandleInt64  = [int64]123456789
                        ProcessID          = 1000
                        WindowState        = 'Visible'
                    }
                }
                { Select-TargetWindowFromMenu -SortBy $SortBy } | Should -Not -Throw
            }
        }
        
        It 'Should reject invalid SortBy values' {
            InModuleScope LastWarAutoScreenshot {
                { Select-TargetWindowFromMenu -SortBy 'InvalidSort' } | Should -Throw
            }
        }
        
        It 'Should accept DetailedView switch' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Get-EnumeratedWindows' -MockWith {
                    return @([PSCustomObject]@{
                        ProcessName       = 'TestProcess'
                        WindowTitle       = 'Test Window'
                        WindowHandle      = [IntPtr]123456789
                        WindowHandleString = '123456789'
                        WindowHandleInt64 = [int64]123456789
                        ProcessID         = 1000
                        WindowState       = 'Visible'
                    })
                }
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return [PSCustomObject]@{
                        ProcessName       = 'TestProcess'
                        WindowTitle       = 'Test Window'
                        WindowHandle      = [IntPtr]123456789
                        WindowHandleString = '123456789'
                        WindowHandleInt64 = [int64]123456789
                        ProcessID         = 1000
                        WindowState       = 'Visible'
                    }
                }
                { Select-TargetWindowFromMenu -DetailedView } | Should -Not -Throw
            }
        }
    }
}

Describe 'Get-SortedWindows' {
    BeforeAll {
        $script:sortWindows = @(
            New-MockWindowData -ProcessName 'zebra' -WindowTitle 'ABC Window' -WindowState 'Visible'
            New-MockWindowData -ProcessName 'alpha' -WindowTitle 'XYZ Window' -WindowState 'Minimized'
            New-MockWindowData -ProcessName 'beta' -WindowTitle 'MNO Window' -WindowState 'Visible'
        )
    }
    
    Context 'When sorting by ProcessName' {
        It 'Should sort ascending by ProcessName' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ sortWindows = $script:sortWindows } {
                $script:currentSort = 'ProcessName'
                $script:sortAscending = $true
                $result = Get-SortedWindows -Windows $sortWindows
                $result[0].ProcessName | Should -Be 'alpha'
                $result[1].ProcessName | Should -Be 'beta'
                $result[2].ProcessName | Should -Be 'zebra'
            }
        }
        It 'Should sort descending by ProcessName' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ sortWindows = $script:sortWindows } {
                $script:currentSort = 'ProcessName'
                $script:sortAscending = $false
                $result = Get-SortedWindows -Windows $sortWindows
                $result[0].ProcessName | Should -Be 'zebra'
                $result[1].ProcessName | Should -Be 'beta'
                $result[2].ProcessName | Should -Be 'alpha'
            }
        }
    }
    
    Context 'When sorting by WindowTitle' {
        It 'Should sort ascending by WindowTitle' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ sortWindows = $script:sortWindows } {
                $script:currentSort = 'WindowTitle'
                $script:sortAscending = $true
                $result = Get-SortedWindows -Windows $sortWindows
                $result[0].WindowTitle | Should -Be 'ABC Window'
                $result[1].WindowTitle | Should -Be 'MNO Window'
                $result[2].WindowTitle | Should -Be 'XYZ Window'
            }
        }
        It 'Should sort descending by WindowTitle' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ sortWindows = $script:sortWindows } {
                $script:currentSort = 'WindowTitle'
                $script:sortAscending = $false
                $result = Get-SortedWindows -Windows $sortWindows
                $result[0].WindowTitle | Should -Be 'XYZ Window'
                $result[1].WindowTitle | Should -Be 'MNO Window'
                $result[2].WindowTitle | Should -Be 'ABC Window'
            }
        }
    }
    
    Context 'When sorting by WindowState' {
        It 'Should sort ascending by WindowState' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ sortWindows = $script:sortWindows } {
                $script:currentSort = 'WindowState'
                $script:sortAscending = $true
                $result = Get-SortedWindows -Windows $sortWindows
                $result[0].WindowState | Should -Be 'Minimized'
                $result[2].WindowState | Should -Be 'Visible'
            }
        }
        It 'Should sort descending by WindowState' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ sortWindows = $script:sortWindows } {
                $script:currentSort = 'WindowState'
                $script:sortAscending = $false
                $result = Get-SortedWindows -Windows $sortWindows
                $result[0].WindowState | Should -Be 'Visible'
            }
        }
    }
}

Describe 'Test-WindowExists' {
    Context 'When validating window handles' {
        It 'Should return true for valid window handle' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Get-WindowTextLength' -MockWith { return 10 }
                $handle = [IntPtr]123456
                $result = Test-WindowExists -WindowHandle $handle
                $result | Should -Be $true
            }
        }

        It 'Should return false when window handle is invalid' {
            InModuleScope LastWarAutoScreenshot {
                Mock -CommandName 'Get-WindowTextLength' -MockWith { return 0 }
                $handle = [IntPtr]0
                $result = Test-WindowExists -WindowHandle $handle
                $result | Should -Be $false
            }
        }
    }
}

Describe 'Select-TargetWindowFromMenu window list scenarios' {
    Context 'When multiple windows with same process name exist' {
        BeforeAll {
            $mockWindows = @(
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Tab 1' -WindowHandle 111
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Tab 2' -WindowHandle 222
                New-MockWindowData -ProcessName 'chrome' -WindowTitle 'Tab 3' -WindowHandle 333
            )
        }
        
        It 'Should allow selection of specific window by index' {
            InModuleScope LastWarAutoScreenshot -Parameters @{ mockWindows = $mockWindows } {
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    return $mockWindows[1]  # Select second chrome window
                }

                $result = $mockWindows | Select-TargetWindowFromMenu

                $result.WindowTitle | Should -Be 'Tab 2'
                $result.WindowHandle | Should -Be 222
            }
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
            InModuleScope LastWarAutoScreenshot -Parameters @{ localMockWindows = $localMockWindows } {
                Mock -CommandName 'Show-MenuLoop' -MockWith {
                    param($Windows)
                    $Windows.Count | Should -Be 2
                    return $localMockWindows[0]
                }
                $result = Select-TargetWindowFromMenu -WindowList $localMockWindows
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}
