## Private/ConsoleApp

Screen functions and helpers for the Phase 3 interactive console UI. All
screens use [Spectre.Console](https://spectreconsole.net/) via the
`ConsoleAppBridge` C# wrapper and accept an `IAnsiConsole` parameter for
testability.

### Files

| File | Purpose |
|------|---------|
| `Test-ConfigValue.ps1` | `Test-ConfigValue` — validates a single config key against the schema in `Get-DefaultModuleSettings.ps1` |
| `Get-StorageInfo.ps1` | Reads screenshot storage path and log folder; returns used/free stats |
| `Invoke-StartupConfigValidation.ps1` | Runs on app start; validates all config keys and surfaces warnings before the main menu loads |
| `Show-ConfigMenuScreen.ps1` | Configuration area selection menu (Logging / Mouse control / Emergency stop / Screenshot settings) |
| `Show-EmergencyStopConfigScreen.ps1` | Edit `EmergencyStop.*` config keys interactively |
| `Show-LoggingConfigScreen.ps1` | Edit `Logging.*` config keys interactively |
| `Show-MainMenu.ps1` | Top-level app menu |
| `Show-MouseControlConfigScreen.ps1` | Edit `MouseControl.*` config keys interactively |
| `Show-StorageInfoScreen.ps1` | Display screenshot storage usage (chart/table) and log file disk usage in two sections; accessible from the top-level main menu |
| `Show-WindowSelectionScreen.ps1` | Enumerate windows, sort, select, and persist the target |

### Adding a new screen

1. Create `Show-MyScreen.ps1` in this folder.
2. Give it a `[Spectre.Console.IAnsiConsole]$Console` parameter defaulting
   to `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`.
3. Add a corresponding `Show-MyScreen.Tests.ps1` in `Tests/ConsoleApp/`.
4. Dispatch to it from `Show-MainMenu.ps1` or `Show-ConfigMenuScreen.ps1`.

See [Docs/ConsoleApp.md](../../Docs/ConsoleApp.md) for the full `IAnsiConsole`
injection pattern and `TestConsole` testing example.

### Test harness

Tests use `Spectre.Console.Testing.TestConsole` to capture rendered output
and push simulated keystrokes. Tests live in `Tests/ConsoleApp/` — see that
folder's `README.md` for setup details.
