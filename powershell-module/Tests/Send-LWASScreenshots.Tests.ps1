BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Send-LWASScreenshots' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Get-UploadProfile {
                [PSCustomObject]@{
                    name                   = 'my-profile'
                    accountName            = 'myaccount'
                    containerName          = 'screenshots'
                    sasTokenEnvVar         = 'LWAS_SEND_TEST_SAS'
                    blobPathPattern        = '{MacroName}/{Date}/{Filename}'
                    maxRetryAttempts       = 3
                    retryBaseDelayMs       = 500
                    deleteLocalAfterUpload = $false
                    deleteLocalAfterDays   = 30
                }
            }
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{
                        StoragePath = 'C:\FakeScreenshots'
                    }
                }
            }
            Mock Invoke-AzureBlobUpload {
                [PSCustomObject]@{ Success = $true; BlobUrl = 'https://blob/file.png'; FilePath = $FilePath }
            }
            Mock Resolve-BlobPath { 'my-profile/2026-03-21/file.png' }
            Mock Remove-Item {}
            Mock Get-ChildItem { @() }
            Mock Write-Progress {}
            Mock Write-Error {}
            Mock Write-Warning {}
        }
        $env:LWAS_SEND_TEST_SAS = 'sv=fake-sas-token'
    }

    AfterEach {
        Remove-Item -Path Env:\LWAS_SEND_TEST_SAS -ErrorAction SilentlyContinue
    }

    It '8.8.1: Profile not found — Write-Error called; no upload attempted' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile { $null }

            Send-LWASScreenshots -UploadProfileName 'missing' -FolderPath 'C:\FakeScreenshots'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*missing*not found*' }
            Should -Invoke Invoke-AzureBlobUpload -Times 0
        }
    }

    It '8.8.2: FolderPath resolves from config when not supplied; Write-Error when StoragePath is empty' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ModuleConfiguration {
                [PSCustomObject]@{
                    Screenshots = [PSCustomObject]@{ StoragePath = '' }
                }
            }

            Send-LWASScreenshots -UploadProfileName 'my-profile'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*StoragePath*' }
            Should -Invoke Invoke-AzureBlobUpload -Times 0
        }
    }

    It '8.8.3: SAS token env var not set — Write-Error called; no upload attempted' {
        Remove-Item -Path Env:\LWAS_SEND_TEST_SAS -ErrorAction SilentlyContinue
        [System.Environment]::SetEnvironmentVariable('LWAS_SEND_TEST_SAS', $null, [System.EnvironmentVariableTarget]::User)

        InModuleScope LastWarAutoScreenshot {
            Mock Test-Path { $true }

            Send-LWASScreenshots -UploadProfileName 'my-profile' -FolderPath 'C:\FakeScreenshots'

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -like '*LWAS_SEND_TEST_SAS*' }
            Should -Invoke Invoke-AzureBlobUpload -Times 0
        }
    }

    It '8.8.4: No files matching Filter — Write-Verbose called; no upload attempted' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ChildItem { @() }
            Mock Test-Path { $true }
            Mock Write-Verbose {}

            Send-LWASScreenshots -UploadProfileName 'my-profile' -FolderPath 'C:\FakeScreenshots'

            Should -Invoke Write-Verbose -Times 1 -ParameterFilter { $Message -like '*No files matching*' }
            Should -Invoke Invoke-AzureBlobUpload -Times 0
        }
    }

    It '8.8.5: Two files present — Invoke-AzureBlobUpload called twice; Write-Progress called; summary written' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ Name = 'a.png'; FullName = 'C:\FakeScreenshots\a.png'; LastWriteTime = (Get-Date) },
                    [PSCustomObject]@{ Name = 'b.png'; FullName = 'C:\FakeScreenshots\b.png'; LastWriteTime = (Get-Date) }
                )
            }
            Mock Test-Path { $true }
            Mock Write-Verbose {}

            Send-LWASScreenshots -UploadProfileName 'my-profile' -FolderPath 'C:\FakeScreenshots'

            Should -Invoke Invoke-AzureBlobUpload -Times 2
            Should -Invoke Write-Progress -Times 3   # once per file + Completed
            Should -Invoke Write-Verbose -Times 1 -ParameterFilter { $Message -like '*Uploaded 2 of 2*' }
        }
    }

    It '8.8.6: One file fails — Write-Warning includes failure count in summary' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ Name = 'a.png'; FullName = 'C:\FakeScreenshots\a.png'; LastWriteTime = (Get-Date) },
                    [PSCustomObject]@{ Name = 'b.png'; FullName = 'C:\FakeScreenshots\b.png'; LastWriteTime = (Get-Date) }
                )
            }
            Mock Test-Path { $true }
            Mock Invoke-AzureBlobUpload {
                if ($FilePath -like '*a.png') {
                    [PSCustomObject]@{ Success = $false; Message = 'upload failed'; FilePath = $FilePath }
                } else {
                    [PSCustomObject]@{ Success = $true; BlobUrl = 'https://blob/b.png'; FilePath = $FilePath }
                }
            }

            Send-LWASScreenshots -UploadProfileName 'my-profile' -FolderPath 'C:\FakeScreenshots'

            Should -Invoke Invoke-AzureBlobUpload -Times 2
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like '*Failed to upload 1*' }
        }
    }

    It '8.8.7: -WhatIf — Invoke-AzureBlobUpload not called' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ Name = 'a.png'; FullName = 'C:\FakeScreenshots\a.png'; LastWriteTime = (Get-Date) }
                )
            }
            Mock Test-Path { $true }

            Send-LWASScreenshots -UploadProfileName 'my-profile' -FolderPath 'C:\FakeScreenshots' -WhatIf

            Should -Invoke Invoke-AzureBlobUpload -Times 0
        }
    }

    It '8.8.8: DeleteLocalAfterUpload = $true — Remove-Item called for each successfully uploaded file' {
        InModuleScope LastWarAutoScreenshot {
            Mock Get-UploadProfile {
                [PSCustomObject]@{
                    name                   = 'my-profile'
                    accountName            = 'myaccount'
                    containerName          = 'screenshots'
                    sasTokenEnvVar         = 'LWAS_SEND_TEST_SAS'
                    blobPathPattern        = '{MacroName}/{Date}/{Filename}'
                    maxRetryAttempts       = 3
                    retryBaseDelayMs       = 500
                    deleteLocalAfterUpload = $true
                    deleteLocalAfterDays   = 30
                }
            }
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ Name = 'a.png'; FullName = 'C:\FakeScreenshots\a.png'; LastWriteTime = (Get-Date) },
                    [PSCustomObject]@{ Name = 'b.png'; FullName = 'C:\FakeScreenshots\b.png'; LastWriteTime = (Get-Date) }
                )
            }
            Mock Test-Path { $true }

            Send-LWASScreenshots -UploadProfileName 'my-profile' -FolderPath 'C:\FakeScreenshots'

            Should -Invoke Remove-Item -Times 2 -ParameterFilter { $Path -like '*\FakeScreenshots\*.png' }
        }
    }

    It '8.8.9: DeleteLocalAfterDays cleanup — Remove-Item called for files older than threshold' {
        InModuleScope LastWarAutoScreenshot {
            $fixedNow  = [datetime]'2026-03-21T12:00:00'
            $oldDate   = [datetime]'2026-02-01T12:00:00'  # older than 30 days ago
            $oldFile   = [PSCustomObject]@{ Name = 'old.png'; FullName = 'C:\FakeScreenshots\old.png'; LastWriteTime = $oldDate }

            Mock Get-Date { $fixedNow }
            Mock Test-Path { $true }
            # First Get-ChildItem call: enumerate files to upload (empty — no uploads needed)
            # Second Get-ChildItem call: cleanup scan finds the old file
            $script:gcCallCount = 0
            Mock Get-ChildItem {
                $script:gcCallCount++
                if ($script:gcCallCount -le 1) { @() } else { @($oldFile) }
            }

            Send-LWASScreenshots -UploadProfileName 'my-profile' -FolderPath 'C:\FakeScreenshots'

            Should -Invoke Remove-Item -Times 1 -ParameterFilter { $LiteralPath -eq 'C:\FakeScreenshots\old.png' }
        }
    }
}
