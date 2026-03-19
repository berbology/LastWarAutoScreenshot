# Private/ConsoleApp

Screen functions and helpers for the interactive console UI. All screens use
[Spectre.Console](https://spectreconsole.net/) via the `ConsoleAppBridge` C#
wrapper and accept an `IAnsiConsole` parameter for testability.

---

## Files

| File | Purpose |
|------|---------|
| `Get-StorageInfo.ps1` | Reads screenshot storage path and log folder; returns used/free disk stats |
| `Invoke-InAlternateScreen.ps1` | Runs a script block inside an alternate terminal screen buffer, restoring the original on exit |
| `Invoke-StartupConfigValidation.ps1` | Runs on app start; validates all config keys and surfaces warnings before the main menu loads |
| `Invoke-YesNoPrompt.ps1` | Displays a yes/no selection prompt and returns a boolean result |
| `Show-ConfigMenuScreen.ps1` | Configuration area menu (Logging / Mouse control / Emergency stop / Screenshot settings / editor / raw config) |
| `Show-EditMacroScreen.ps1` | Edit macro screen — allows the user to rename, reorder, and modify individual actions in a saved macro |
| `Show-EmergencyStopConfigScreen.ps1` | Edit `EmergencyStop.*` config keys interactively |
| `Show-LoggingConfigScreen.ps1` | Edit `Logging.*` config keys interactively |
| `Show-MainMenu.ps1` | Top-level app menu; conditionally shows Record/Run/Manage macro options based on state |
| `Show-ManageMacrosScreen.ps1` | View, edit, and delete saved macros |
| `Show-MouseControlConfigScreen.ps1` | Edit `MouseControl.*` config keys interactively |
| `Show-RecordMacroScreen.ps1` | Macro recording screen — guides the user through building a macro action by action |
| `Show-RunMacroScreen.ps1` | Select and execute a saved macro; shows a pre-run summary and confirmation prompt |
| `Show-ScheduleScreen.ps1` | View, create, and remove Windows Scheduled Tasks that run LWAS macros |
| `Show-ScreenshotConfigScreen.ps1` | Edit `Screenshots.*` config keys (storage path, filename pattern, similarity check settings) |
| `Show-StorageInfoScreen.ps1` | Display screenshot storage usage and log file disk usage; accessible from the main menu |
| `Show-WindowSelectionScreen.ps1` | Enumerate windows, sort, select, and persist the target window |
| `Test-ConfigValue.ps1` | Validate a single config key against the schema in `Get-DefaultModuleSettings.ps1` |

---

## Adding a new screen

1. Create `Show-MyScreen.ps1` in this folder.
2. Give it a `[Spectre.Console.IAnsiConsole]$Console` parameter defaulting
   to `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`.
3. Add a corresponding `Show-MyScreen.Tests.ps1` in `Tests/ConsoleApp/`.
4. Dispatch to it from `Show-MainMenu.ps1` or `Show-ConfigMenuScreen.ps1`.

For the full guide including the `IAnsiConsole` injection pattern and
`TestConsole` testing example, see [Docs/Developer.md](../../Docs/Developer.md).
