# ConsoleApp Tests

Pester v5 test suite for the interactive console UI layer. Each file covers
one screen function or helper from `Private/ConsoleApp/`.

---

## Test harness setup

Tests inject `[Spectre.Console.Testing.TestConsole]` in place of the real
terminal. Load the testing DLL in `BeforeAll`:

```powershell
BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    $testingDll = Join-Path $PSScriptRoot '..\..\lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}
```

Then in each test:

```powershell
It 'renders the main menu' {
    InModuleScope LastWarAutoScreenshot {
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Input.PushTextWithEnter('Exit')
        Show-MainMenu -Console $tc
        $tc.Output | Should -Match 'Exit'
    }
}
```

Use `$tc.Input.PushTextWithEnter(...)` to simulate user selections and assert
on `$tc.Output` for rendered text. All tests use `InModuleScope LastWarAutoScreenshot`
so private functions are accessible.

---

## Files

| File | Covers |
|------|--------|
| `ConsoleAppBridge.Tests.ps1` | `[LastWarAutoScreenshot.ConsoleAppBridge]` type and factory methods |
| `ConfigValidation.Tests.ps1` | `Test-ConfigValue` — all type/range/enum/nullable scenarios |
| `Get-StorageInfo.Tests.ps1` | Storage stats calculation, unconfigured path, access denied |
| `Invoke-StartupConfigValidation.Tests.ps1` | Startup validation: missing file, valid config, invalid values, bad JSON |
| `Show-ConfigMenuScreen.Tests.ps1` | Config area menu routing |
| `Show-EditMacroScreen.Tests.ps1` | Edit macro screen — action editing and saving |
| `Show-EmergencyStopConfigScreen.Tests.ps1` | Emergency stop config — VKey code parsing and validation |
| `Show-LoggingConfigScreen.Tests.ps1` | Logging config edit/save/reset/discard |
| `Show-MainMenu.Tests.ps1` | Main menu rendering and return values |
| `Show-ManageMacrosScreen.Tests.ps1` | Manage macros screen — list, edit, delete |
| `Show-MouseControlConfigScreen.Tests.ps1` | Mouse control config — bool prompts, intArray validation |
| `Show-RecordMacroScreen.Tests.ps1` | Macro recording screen — building action sequences |
| `Show-RunMacroScreen.Tests.ps1` | Run macro screen — selection and execution dispatch |
| `Show-ScheduleScreen.Tests.ps1` | Manage schedules screen — list, create, and remove scheduled tasks |
| `Show-ScreenshotConfigScreen.Tests.ps1` | Screenshot config — storage path, filename pattern, similarity settings |
| `Show-StorageInfoScreen.Tests.ps1` | Storage screen rendering: not-configured panel, warning at 90%, log section |
| `Show-WindowSelectionScreen.Tests.ps1` | Window enumeration, sort, selection, handle validation, save |
| `Start-LWASConsole.Tests.ps1` | App entry point loop, config validation dispatch, screen routing |
