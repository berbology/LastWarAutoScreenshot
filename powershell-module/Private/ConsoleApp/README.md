# Private/ConsoleApp

Screen functions and helpers for the interactive console UI. All screens use
[Spectre.Console](https://spectreconsole.net/) via the `ConsoleAppBridge` C#
wrapper and accept an `IAnsiConsole` parameter for testability.

## Files

| File | Purpose |
|------|---------|
| `Get-StorageInfo.ps1` | Reads the screenshot storage path and log folder; returns used/free stats |
| `Invoke-InAlternateScreen.ps1` | Runs a scriptblock inside an alternate terminal screen buffer; thin PowerShell wrapper over `ConsoleAppBridge::RunInAlternateScreen` to enable Pester mocking |
| `Invoke-StartupConfigValidation.ps1` | Runs on app start; validates all config keys and surfaces warnings before the main menu loads |
| `Invoke-YesNoPrompt.ps1` | Displays a yes/no `SelectionPrompt` and returns `$true` for Yes, `$false` for No |
| `Show-ConfigMenuScreen.ps1` | Configuration area selection menu (Logging / Mouse control / Emergency stop / Screenshot settings) |
| `Show-EditMacroScreen.ps1` | Edit a saved macro: rename it, rename individual actions, or reorder the action sequence |
| `Show-EmergencyStopConfigScreen.ps1` | Edit `EmergencyStop.*` config keys interactively |
| `Show-LoggingConfigScreen.ps1` | Edit `Logging.*` config keys interactively |
| `Show-MainMenu.ps1` | Top-level app menu |
| `Show-ManageMacrosScreen.ps1` | Manage macros: view details, edit, or delete saved macros |
| `Show-MouseControlConfigScreen.ps1` | Edit `MouseControl.*` config keys interactively |
| `Show-RecordMacroScreen.ps1` | Record a new macro: name it, add actions interactively, save to `Private/Macros/` |
| `Show-RunMacroScreen.ps1` | Select and run a saved macro; shows action summary and pre-flight checks before execution |
| `Show-ScheduleScreen.ps1` | Manage scheduled tasks: view, create, and remove Windows Scheduled Tasks for running macros |
| `Show-ScreenshotConfigScreen.ps1` | Edit `Screenshots.*` config keys interactively |
| `Show-StorageInfoScreen.ps1` | Display screenshot storage usage (chart/table) and log file disk usage in two sections |
| `Show-WindowSelectionScreen.ps1` | Enumerate windows, sort, select, and persist the target window |
| `Test-ConfigValue.ps1` | Validates a single config key/value against the schema in `Get-DefaultModuleSettings.ps1` |

## Adding a new screen

1. Create `Show-MyScreen.ps1` in this folder.
2. Give it a `[Spectre.Console.IAnsiConsole]$Console` parameter defaulting
   to `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`.
3. Add a corresponding `Show-MyScreen.Tests.ps1` in `Tests/ConsoleApp/`.
4. Dispatch to it from `Show-MainMenu.ps1` or `Show-ConfigMenuScreen.ps1`.

See [Docs/Developer.md](../../Docs/Developer.md#adding-a-new-screen) for the
full guide including the minimal screen template and testing pattern.
