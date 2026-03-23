BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Remove-Module LastWarAutoScreenshot -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force
}

Describe 'Invoke-WithRetry' -Tag 'Unit' {

    BeforeEach {
        InModuleScope LastWarAutoScreenshot {
            Mock Write-LastWarLog {}
            Mock Start-Sleep {}
        }
    }

    It '3.2.1: Scriptblock that succeeds on first attempt returns its result without calling Start-Sleep' {
        InModuleScope LastWarAutoScreenshot {
            $result = Invoke-WithRetry -ScriptBlock { 'ok' } -MaxAttempts 3 -BaseDelayMs 100
            $result | Should -Be 'ok'
            Should -Invoke Start-Sleep -Times 0
        }
    }

    It '3.2.2: Scriptblock that fails once with retryable code then succeeds returns result; Write-LastWarLog Warning called once' {
        InModuleScope LastWarAutoScreenshot {
            $script:retryCallCount = 0
            $sb = {
                $script:retryCallCount++
                if ($script:retryCallCount -eq 1) {
                    throw [System.Net.Http.HttpRequestException]::new(
                        '429',
                        $null,
                        [System.Net.HttpStatusCode]::TooManyRequests
                    )
                }
                return 'success'
            }

            $result = Invoke-WithRetry -ScriptBlock $sb -MaxAttempts 3 -BaseDelayMs 100

            $result | Should -Be 'success'
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Times 1
        }
    }

    It '3.2.3: Scriptblock that always fails with retryable code throws after MaxAttempts; Write-LastWarLog Warning called MaxAttempts-1 times' {
        InModuleScope LastWarAutoScreenshot {
            $sb = {
                throw [System.Net.Http.HttpRequestException]::new(
                    '503',
                    $null,
                    [System.Net.HttpStatusCode]::ServiceUnavailable
                )
            }

            { Invoke-WithRetry -ScriptBlock $sb -MaxAttempts 3 -BaseDelayMs 100 } | Should -Throw

            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Times 2
        }
    }

    It '3.2.4: Scriptblock that fails with non-retryable code 404 throws immediately without Start-Sleep' {
        InModuleScope LastWarAutoScreenshot {
            $sb = {
                throw [System.Net.Http.HttpRequestException]::new(
                    '404',
                    $null,
                    [System.Net.HttpStatusCode]::NotFound
                )
            }

            { Invoke-WithRetry -ScriptBlock $sb -MaxAttempts 3 -BaseDelayMs 100 } | Should -Throw
            Should -Invoke Start-Sleep -Times 0
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Times 0
        }
    }

    It '3.2.5: Scriptblock that fails with a generic exception throws immediately without retry' {
        InModuleScope LastWarAutoScreenshot {
            $sb = {
                throw [System.InvalidOperationException]::new('Something went wrong')
            }

            { Invoke-WithRetry -ScriptBlock $sb -MaxAttempts 3 -BaseDelayMs 100 } | Should -Throw
            Should -Invoke Start-Sleep -Times 0
            Should -Invoke Write-LastWarLog -ParameterFilter { $Level -eq 'Warning' } -Times 0
        }
    }

    It '3.2.6: Delay is bounded at 30000ms when BaseDelayMs is very large' {
        InModuleScope LastWarAutoScreenshot {
            $sb = {
                throw [System.Net.Http.HttpRequestException]::new(
                    '429',
                    $null,
                    [System.Net.HttpStatusCode]::TooManyRequests
                )
            }

            { Invoke-WithRetry -ScriptBlock $sb -MaxAttempts 3 -BaseDelayMs 100000 } | Should -Throw

            # Start-Sleep should never have been called with more than 30000ms
            Should -Invoke Start-Sleep -ParameterFilter { $Milliseconds -gt 30000 } -Times 0
            # And it should have been called (retries did happen)
            Should -Invoke Start-Sleep -Times 2
        }
    }
}
