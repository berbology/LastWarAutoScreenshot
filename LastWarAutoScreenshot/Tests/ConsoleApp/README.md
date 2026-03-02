# ConsoleApp Tests

Pester v5 test suite for the Phase 3 console UI layer. Each file covers
one screen or helper function from `Private/ConsoleApp/`.

## Test infrastructure

Tests inject `[Spectre.Console.Testing.TestConsole]` instead of the real
terminal. Load the testing DLL in `BeforeAll`:

```powershell
BeforeAll {
    $testingDll = Join-Path $PSScriptRoot '..\..\lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}
```

Then in each test:

```powershell
$tc = [Spectre.Console.Testing.TestConsole]::new()
$tc.Input.PushTextWithEnter('Exit')      # simulate user input
Show-MainMenu -Console $tc
$tc.Output | Should -Match 'Exit'        # assert on rendered output
```

All tests use `InModuleScope LastWarAutoScreenshot` so private functions
are accessible.

## Files

| File | Covers |
|------|--------|
| `ConsoleAppBridge.Tests.ps1` | `[LastWarAutoScreenshot.ConsoleAppBridge]` type and factory methods |
| `ConfigValidation.Tests.ps1` | `Test-ConfigValue` — all type/range/enum/nullable scenarios |
| `Invoke-StartupConfigValidation.Tests.ps1` | Startup validation: missing file, valid config, invalid values, bad JSON |
| `Show-MainMenu.Tests.ps1` | Main menu rendering and return values |
| `Start-LastWarAutoScreenshot.Tests.ps1` | App entry point loop, config validation dispatch, screen routing |
| `Show-WindowSelectionScreen.Tests.ps1` | Window enumeration, sort, selection, handle validation, save |
| `Show-ConfigMenuScreen.Tests.ps1` | Config area menu routing |
| `Show-LoggingConfigScreen.Tests.ps1` | Logging config edit/save/reset/discard |
| `Show-MouseControlConfigScreen.Tests.ps1` | Mouse control config — bool prompts, intArray validation |
| `Show-EmergencyStopConfigScreen.Tests.ps1` | Emergency stop config — VKey code parsing and validation |
| `Get-StorageInfo.Tests.ps1` | Storage stats calculation, unconfigured path, access denied |
| `Show-StorageInfoScreen.Tests.ps1` | Storage screen rendering, warning at 90%, save/discard |

