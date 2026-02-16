BeforeAll {
    # Import the logger function
    . $PSScriptRoot/Write-LastWarLog.ps1
}

describe 'Write-LastWarLog (Mocked)' {
    Context 'Invocation and parameter passing' {
        It 'Should call Write-LastWarLog with correct parameters' {
            Mock -CommandName Write-LastWarLog -MockWith { }
            function UnderTest {
                Write-LastWarLog -Message 'Mocked' -Level 'Error' -FunctionName 'TestFunc' -Context 'TestCtx' -StackTrace 'Stack' -ForceLog
            }
            UnderTest
            Should -Invoke Write-LastWarLog -ParameterFilter {
                $Message -eq 'Mocked' -and $Level -eq 'Error' -and $FunctionName -eq 'TestFunc' -and $Context -eq 'TestCtx' -and $StackTrace -eq 'Stack' -and $ForceLog
            } -Exactly 1
        }
        It 'Should not call Write-LastWarLog if not required' {
            Mock -CommandName Write-LastWarLog -MockWith { }
            function UnderTest {}
            UnderTest
            Should -Not -Invoke Write-LastWarLog
        }
    }
}
