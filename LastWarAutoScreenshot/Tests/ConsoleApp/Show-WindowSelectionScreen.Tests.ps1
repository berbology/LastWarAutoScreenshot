BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    # Spectre.Console.Testing.dll ships in lib\test\ and is required for TestConsole
    $testingDll = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

Describe 'Show-WindowSelectionScreen' {

    # ════════════════════════════════════════════════════════════════════════
    # Context: No windows found after enumeration
    # ════════════════════════════════════════════════════════════════════════
    Context 'When Get-EnumeratedWindows returns an empty list' {

        It 'Returns $null' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows { @() }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Confirm first sort option (Process name A-Z)

                $result = Show-WindowSelectionScreen -Console $tc
                $result | Should -BeNullOrEmpty
            }
        }

        It 'Writes an error panel containing "No windows found" text to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows { @() }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-WindowSelectionScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'No windows found'
            }
        }

        It 'Calls Write-LastWarLog with Level Error when no windows are found' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows { @() }
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-WindowSelectionScreen -Console $tc | Out-Null
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Error' } -Exactly 1
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Windows found, user navigates to [Back to main menu]
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects [Back to main menu]' {

        It 'Returns $null without calling Save-ModuleConfiguration' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Two windows: sorted A-Z gives [Back to main menu] (0) → 1: calc (1) → 2: notepad (2)
                Mock Get-EnumeratedWindows {
                    @(
                        [PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 },
                        [PSCustomObject]@{ ProcessName='calc';    WindowTitle='Calculator';         WindowHandle=[IntPtr]::new(1002); WindowState='Visible'; ProcessID=200 }
                    )
                }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort: first option (Process name A-Z)
                # Choices: [0] [Back to main menu], [1] 1: calc, [2] 2: notepad
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select [Back to main menu] (index 0, default)

                $result = Show-WindowSelectionScreen -Console $tc
                $result | Should -BeNullOrEmpty
                Should -Not -Invoke Save-ModuleConfiguration
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Windows found and user selects a valid window
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the user selects a valid window' {

        It 'Returns the selected window object' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid { $true }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort: Process name A-Z
                # Choices: [0] [Back to main menu], [1] 1: notepad
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move past [Back to main menu] to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad

                $result = Show-WindowSelectionScreen -Console $tc
                $result | Should -Not -BeNullOrEmpty
                $result.ProcessName | Should -Be 'notepad'
                $result.WindowTitle | Should -Be 'Untitled - Notepad'
            }
        }

        It 'Calls Save-ModuleConfiguration with the selected window object' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid { $true }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort: Process name A-Z
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move past [Back to main menu] to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad

                Show-WindowSelectionScreen -Console $tc | Out-Null
                Should -Invoke Save-ModuleConfiguration -Exactly 1 -ParameterFilter {
                    $WindowObject.ProcessName -eq 'notepad'
                }
            }
        }

        It 'Console output contains both window titles when two windows are enumerated' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @(
                        [PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 },
                        [PSCustomObject]@{ ProcessName='calc';    WindowTitle='Calculator';         WindowHandle=[IntPtr]::new(1002); WindowState='Visible'; ProcessID=200 }
                    )
                }
                Mock Test-WindowHandleValid { $true }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Sort
                $tc.Input.PushKey([ConsoleKey]::Enter)  # Select first window (calc after A-Z sort)

                Show-WindowSelectionScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'Untitled - Notepad'
                $tc.Output | Should -Match 'Calculator'
            }
        }

        It 'Writes a success panel containing "selected and saved" to the console' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid { $true }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort: Process name A-Z
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move past [Back to main menu] to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad

                Show-WindowSelectionScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'selected and saved'
            }
        }

        It 'The success panel output contains the selected window title' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid { $true }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                Show-WindowSelectionScreen -Console $tc | Out-Null
                $tc.Output | Should -Match 'Untitled - Notepad'
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Selected window handle is no longer valid (window closed)
    # $script:_wssHandleCallCount is set/reset in BeforeEach/AfterEach so that
    # each It block starts with a clean counter in the module's script scope.
    # ════════════════════════════════════════════════════════════════════════
    Context 'When the selected window handle is invalid on first attempt' {

        BeforeEach {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                $script:_wssHandleCallCount = 0
            }
        }

        AfterEach {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Remove-Variable -Name '_wssHandleCallCount' -Scope Script -ErrorAction SilentlyContinue
            }
        }

        It 'Shows an error panel containing "has closed" and subsequently returns the window on the second valid attempt' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid {
                    $script:_wssHandleCallCount++
                    return ($script:_wssHandleCallCount -gt 1)  # $false on call 1, $true on call 2+
                }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort selection
                # Loop 1: handle invalid - select notepad (index 1, past [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)
                # Loop 2: handle valid - select notepad again (index 1, past [Back to main menu])
                $tc.Input.PushKey([ConsoleKey]::DownArrow)
                $tc.Input.PushKey([ConsoleKey]::Enter)

                $result = Show-WindowSelectionScreen -Console $tc
                $result | Should -Not -BeNullOrEmpty
                $tc.Output | Should -Match 'has closed'
            }
        }

        It 'Calls Test-WindowHandleValid exactly twice when the first call returns false' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid {
                    $script:_wssHandleCallCount++
                    return ($script:_wssHandleCallCount -gt 1)
                }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort selection
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad (loop 1 - invalid)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad (loop 2 - valid)

                Show-WindowSelectionScreen -Console $tc | Out-Null
                Should -Invoke Test-WindowHandleValid -Exactly 2
            }
        }

        It 'Calls Write-LastWarLog with Level Error when the window handle is invalid' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid {
                    $script:_wssHandleCallCount++
                    return ($script:_wssHandleCallCount -gt 1)
                }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort selection
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad (loop 1 - invalid)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad (loop 2 - valid)

                Show-WindowSelectionScreen -Console $tc | Out-Null
                Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Error' } -Exactly 1
            }
        }

        It 'Re-enumerates windows on the second loop iteration' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid {
                    $script:_wssHandleCallCount++
                    return ($script:_wssHandleCallCount -gt 1)
                }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort selection
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad (loop 1 - invalid)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad (loop 2 - valid)

                Show-WindowSelectionScreen -Console $tc | Out-Null
                # Called once per loop iteration: first (invalid) + second (valid) = 2 calls
                Should -Invoke Get-EnumeratedWindows -Exactly 2
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Sort selection is propagated to the table and prompt ordering
    # ════════════════════════════════════════════════════════════════════════
    Context 'When sort selection is propagated to the window table' {

        It 'Displays windows in Process name A-Z order when the first (A-Z) sort option is confirmed' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                # Intentionally reversed order in mock to confirm sort is applied
                Mock Get-EnumeratedWindows {
                    @(
                        [PSCustomObject]@{ ProcessName='zapp';  WindowTitle='Zapp App';  WindowHandle=[IntPtr]::new(2001); WindowState='Visible'; ProcessID=300 },
                        [PSCustomObject]@{ ProcessName='alpha'; WindowTitle='Alpha App'; WindowHandle=[IntPtr]::new(2002); WindowState='Visible'; ProcessID=400 }
                    )
                }
                Mock Test-WindowHandleValid { $true }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort: Process name (A-Z) - first option
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move past choice 0 (alpha after A-Z)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move past choice 1 (zapp)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select [Back to main menu]

                Show-WindowSelectionScreen -Console $tc | Out-Null

                # In A-Z sort, 'alpha' row appears in the table before 'zapp' row
                $tcOutput    = $tc.Output
                $alphaOffset = $tcOutput.IndexOf('alpha')
                $zappOffset  = $tcOutput.IndexOf('zapp')
                $alphaOffset | Should -BeLessThan $zappOffset
            }
        }

        It 'Displays windows in Process name Z-A order when the second (Z-A) sort option is selected' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @(
                        [PSCustomObject]@{ ProcessName='alpha'; WindowTitle='Alpha App'; WindowHandle=[IntPtr]::new(3001); WindowState='Visible'; ProcessID=500 },
                        [PSCustomObject]@{ ProcessName='zapp';  WindowTitle='Zapp App';  WindowHandle=[IntPtr]::new(3002); WindowState='Visible'; ProcessID=600 }
                    )
                }
                Mock Test-WindowHandleValid { $true }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Sort: Process name (Z-A) - second option
                $tc.Input.PushKey([ConsoleKey]::Enter)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move past choice 0 (zapp after Z-A)
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move past choice 1 (alpha)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select [Back to main menu]

                Show-WindowSelectionScreen -Console $tc | Out-Null

                # In Z-A sort, 'zapp' row appears before 'alpha' row
                $tcOutput    = $tc.Output
                $alphaOffset = $tcOutput.IndexOf('alpha')
                $zappOffset  = $tcOutput.IndexOf('zapp')
                $zappOffset | Should -BeLessThan $alphaOffset
            }
        }
    }

    # ════════════════════════════════════════════════════════════════════════
    # Context: Return value shape
    # ════════════════════════════════════════════════════════════════════════
    Context 'Return value shape on successful selection' {

        It 'Returns an object with ProcessName, WindowTitle, and WindowHandle properties' {
            InModuleScope -ModuleName 'LastWarAutoScreenshot' {
                Mock Get-EnumeratedWindows {
                    @([PSCustomObject]@{ ProcessName='notepad'; WindowTitle='Untitled - Notepad'; WindowHandle=[IntPtr]::new(1001); WindowState='Visible'; ProcessID=100 })
                }
                Mock Test-WindowHandleValid { $true }
                Mock Save-ModuleConfiguration {}
                Mock Write-LastWarLog {}

                $tc = [Spectre.Console.Testing.TestConsole]::new()
                $tc.Profile.Capabilities.Interactive = $true
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Sort: Process name A-Z
                $tc.Input.PushKey([ConsoleKey]::DownArrow)  # Move past [Back to main menu] to notepad (index 1)
                $tc.Input.PushKey([ConsoleKey]::Enter)      # Select notepad

                $result = Show-WindowSelectionScreen -Console $tc
                $result.PSObject.Properties.Name | Should -Contain 'ProcessName'
                $result.PSObject.Properties.Name | Should -Contain 'WindowTitle'
                $result.PSObject.Properties.Name | Should -Contain 'WindowHandle'
            }
        }
    }
}

