BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Install-LWAS' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            # Prevent all filesystem and process side effects
            Mock Test-IsAdministrator { return $true }
            Mock Get-DotNetRuntimes   { return 'Microsoft.NETCore.App 9.0.1 [C:\Program Files\dotnet\shared\Microsoft.NETCore.App\9.0.1]' }
            Mock Invoke-WingetInstall {}
            Mock Import-PowerShellDataFile { return @{ ModuleVersion = '1.0.0' } }
            Mock Test-Path {
                param($Path)
                # Return $false for install path and AppData so the "does not exist" branch runs by default
                return $false
            }
            Mock Copy-Item   {}
            Mock Remove-Item {}
            Mock New-Item    {}
            Mock Test-EventLogSourceExists { return $false }
            Mock Add-EventLogSource {}
            Mock Invoke-WebRequest {}
            Mock Expand-Archive {}
            Mock Read-Host { return 'N' }
        }
    }

    Context 'Admin check' {

        It '7.3: not elevated — writes warning and returns without calling Copy-Item' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-IsAdministrator { return $false }

                Install-LWAS 3>&1 | Out-Null

                Should -Invoke Copy-Item -Times 0
            }
        }
    }

    Context '.NET 9.0 check' {

        It '7.4: elevated + .NET 9.0 present — Invoke-WingetInstall not called' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-DotNetRuntimes { return 'Microsoft.NETCore.App 9.0.1 [C:\Program Files\dotnet]' }

                Install-LWAS 2>&1 | Out-Null

                Should -Invoke Invoke-WingetInstall -Times 0
            }
        }

        It '7.5: elevated + .NET 9.0 missing + user answers N — returns early; Copy-Item not called' {
            InModuleScope LastWarAutoScreenshot {
                Mock Get-DotNetRuntimes { return 'Microsoft.NETCore.App 8.0.1 [C:\Program Files\dotnet]' }
                Mock Read-Host { return 'N' }

                Install-LWAS 2>&1 | Out-Null

                Should -Invoke Copy-Item -Times 0
            }
        }
    }

    Context 'Module copy' {

        It '7.6: install path does not exist — Copy-Item called with destination containing version subfolder 1.0.0' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    # DLL targets return $true so download is not triggered; installPath is $false
                    if ($Path -match 'Spectre\.Console') { return $true }
                    return $false
                }

                $output = Install-LWAS 2>&1

                Should -Invoke Copy-Item -Times 1 -ParameterFilter {
                    $Destination -match '1\.0\.0'
                }
            }
        }

        It '7.7: install path exists + no -Force — Copy-Item not called; warning contains already installed' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    if ($Path -match 'Spectre\.Console') { return $true }
                    if ($Path -match '1\.0\.0') { return $true }
                    return $false
                }

                $output = Install-LWAS 3>&1

                Should -Invoke Copy-Item -Times 0
                Should -Invoke Read-Host -Times 0
                ($output -like '*already installed*') | Should -Not -BeNullOrEmpty
            }
        }

        It '7.8: install path exists + -Force switch — Copy-Item called without prompting' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    if ($Path -match 'Spectre\.Console') { return $true }
                    if ($Path -match '1\.0\.0') { return $true }
                    return $false
                }

                Install-LWAS -Force 2>&1 | Out-Null

                Should -Invoke Copy-Item -Times 1
                Should -Invoke Read-Host -Times 0 -ParameterFilter {
                    $Prompt -match 'Overwrite'
                }
            }
        }
    }

    Context 'Event Log source' {

        It '7.9: source does not exist — Add-EventLogSource called with correct parameters' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    if ($Path -match 'Spectre\.Console') { return $true }
                    return $false
                }
                Mock Test-EventLogSourceExists { return $false }

                Install-LWAS 2>&1 | Out-Null

                Should -Invoke Add-EventLogSource -Times 1 -ParameterFilter {
                    $Source -eq 'LastWarAutoScreenshot' -and $LogName -eq 'Application'
                }
            }
        }

        It '7.10: source already exists — Add-EventLogSource not called' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    if ($Path -match 'Spectre\.Console') { return $true }
                    return $false
                }
                Mock Test-EventLogSourceExists { return $true }

                Install-LWAS 2>&1 | Out-Null

                Should -Invoke Add-EventLogSource -Times 0
            }
        }
    }

    Context 'AppData directory' {

        It '7.11: appdata directory does not exist — New-Item called with the appdata path' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    if ($Path -match 'Spectre\.Console') { return $true }
                    if ($Path -match 'APPDATA|AppData') { return $false }
                    return $false
                }

                Install-LWAS 2>&1 | Out-Null

                Should -Invoke New-Item -Times 1 -ParameterFilter {
                    $Path -match 'AppData' -and $ItemType -eq 'Directory'
                }
            }
        }

        It '7.12: appdata directory already exists — New-Item not called; output contains already exists' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    if ($Path -match 'Spectre\.Console') { return $true }
                    if ($Path -match 'AppData|APPDATA') { return $true }
                    return $false
                }

                $output = Install-LWAS -Verbose 4>&1

                Should -Invoke New-Item -Times 0 -ParameterFilter {
                    $Path -match 'AppData' -and $ItemType -eq 'Directory'
                }
                ($output -like '*already exists*') | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'DLL verification' {

        It '7.13: Spectre.Console.dll present — Invoke-WebRequest not called; output contains already present' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    # All paths return $true — main DLL is present
                    return $true
                }
                Mock Read-Host { return 'Y' }

                $output = Install-LWAS -Force -Verbose 4>&1

                Should -Invoke Invoke-WebRequest -Times 0
                $combined = $output -join ' '
                $combined | Should -BeLike '*Spectre.Console.dll already present*'
            }
        }

        It '7.13b: Spectre.Console.Testing.dll not downloaded when -IncludeTests is omitted, even if DLL is absent' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    if ($Path -match 'Spectre\.Console') { return $false }
                    return $true
                }
                Mock Read-Host { return 'Y' }

                Install-LWAS -Force 2>&1 | Out-Null

                Should -Invoke Invoke-WebRequest -Times 0 -ParameterFilter {
                    $Uri -match 'Testing'
                }
            }
        }

        It '7.14: Spectre.Console.dll missing — Invoke-WebRequest called with URL matching Spectre.Console but not Testing' {
            InModuleScope LastWarAutoScreenshot {
                Mock Test-Path {
                    param($Path)
                    if ($Path -match 'Spectre\.Console') { return $false }
                    return $false
                }

                Install-LWAS 2>&1 | Out-Null

                Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter {
                    $Uri -match 'Spectre\.Console' -and $Uri -notmatch 'Testing'
                }
            }
        }
    }
}
