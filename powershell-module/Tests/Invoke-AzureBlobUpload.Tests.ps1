BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Invoke-AzureBlobUpload' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Start-Sleep {}
        }
    }

    It '4.2.1: Successful upload calls Invoke-WebRequest with correct URL, method, and headers; returns Success=true with BlobUrl set' {
        $testFile = Join-Path $TestDrive 'upload.png'
        [System.IO.File]::WriteAllBytes($testFile, [byte[]]@(137, 80, 78, 71))

        InModuleScope LastWarAutoScreenshot -Parameters @{ filePath = $testFile } {
            Mock Invoke-WebRequest {}

            $result = Invoke-AzureBlobUpload `
                -FilePath $filePath `
                -AccountName 'myaccount' `
                -ContainerName 'screenshots' `
                -BlobPath 'my-macro/2026-03-21/upload.png' `
                -SasToken 'sv=2021-06-08&sig=abc'

            $result.Success | Should -BeTrue
            $result.BlobUrl | Should -Not -BeNullOrEmpty

            Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter {
                $Method -eq 'Put' -and
                $Headers['x-ms-blob-type'] -eq 'BlockBlob' -and
                $UseBasicParsing -eq $true
            }
        }
    }

    It '4.2.2: URL construction embeds BlobPath between container name and SAS token with correct separators' {
        $testFile = Join-Path $TestDrive 'url-check.png'
        [System.IO.File]::WriteAllBytes($testFile, [byte[]]@(1, 2, 3))

        InModuleScope LastWarAutoScreenshot -Parameters @{ filePath = $testFile } {
            $capturedUri = $null
            Mock Invoke-WebRequest { $script:capturedUri = $Uri }

            Invoke-AzureBlobUpload `
                -FilePath $filePath `
                -AccountName 'acct' `
                -ContainerName 'mycontainer' `
                -BlobPath 'macro/2026-03-21/file.png' `
                -SasToken 'sig=xyz' | Out-Null

            $script:capturedUri | Should -BeLike 'https://acct.blob.core.windows.net/mycontainer/macro/2026-03-21/file.png`?sig=xyz'
            $script:capturedUri | Should -Not -BeLike '*//macro*'
            $script:capturedUri | Should -Not -BeLike '*`?`?*'
        }
    }

    It '4.2.3: Invoke-WebRequest failure with 429 leads to retry via Invoke-WithRetry; returns Success=false after retries exhausted' {
        $testFile = Join-Path $TestDrive 'retry-test.png'
        [System.IO.File]::WriteAllBytes($testFile, [byte[]]@(1, 2, 3))

        InModuleScope LastWarAutoScreenshot -Parameters @{ filePath = $testFile } {
            Mock Invoke-WebRequest {
                throw [System.Net.Http.HttpRequestException]::new(
                    '429',
                    $null,
                    [System.Net.HttpStatusCode]::TooManyRequests
                )
            }

            $result = Invoke-AzureBlobUpload `
                -FilePath $filePath `
                -AccountName 'acct' `
                -ContainerName 'c' `
                -BlobPath 'blob/path' `
                -SasToken 'sig=x' `
                -MaxRetryAttempts 2 `
                -RetryBaseDelayMs 10

            $result.Success | Should -BeFalse
            $result.Message | Should -Not -BeNullOrEmpty
        }
    }

    It '4.2.4: Invoke-WebRequest failure with 403 returns Success=false without retry and logs error' {
        $testFile = Join-Path $TestDrive 'forbidden.png'
        [System.IO.File]::WriteAllBytes($testFile, [byte[]]@(1, 2, 3))

        InModuleScope LastWarAutoScreenshot -Parameters @{ filePath = $testFile } {
            Mock Invoke-WebRequest {
                throw [System.Net.Http.HttpRequestException]::new(
                    '403',
                    $null,
                    [System.Net.HttpStatusCode]::Forbidden
                )
            }

            $result = Invoke-AzureBlobUpload `
                -FilePath $filePath `
                -AccountName 'acct' `
                -ContainerName 'c' `
                -BlobPath 'blob/path' `
                -SasToken 'sig=bad'

            $result.Success | Should -BeFalse
            Should -Invoke Start-Sleep -Times 0
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Error' } -Times 1
        }
    }

    It '4.2.5: File does not exist returns Success=false with descriptive message before any web request' {
        InModuleScope LastWarAutoScreenshot {
            Mock Invoke-WebRequest {}

            $result = Invoke-AzureBlobUpload `
                -FilePath 'C:\nonexistent\missing.png' `
                -AccountName 'acct' `
                -ContainerName 'c' `
                -BlobPath 'blob/path' `
                -SasToken 'sig=x'

            $result.Success | Should -BeFalse
            $result.Message | Should -Not -BeNullOrEmpty
            $result.FilePath | Should -Be 'C:\nonexistent\missing.png'
            Should -Invoke Invoke-WebRequest -Times 0
        }
    }
}
