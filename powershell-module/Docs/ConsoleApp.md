## Console App

The interactive console app (`Start-LWASConsole`) is the primary
interface for all setup, configuration, and macro management.
It uses [Spectre.Console](https://spectreconsole.net/) for rich terminal
rendering.

### Entry point

```powershell
Import-Module .\powershell-module\LastWarAutoScreenshot.psd1
Start-LWASConsole
```

On first run with no config file: defaults are written to
`$env:APPDATA\LastWarAutoScreenshot\ModuleConfig.jsonc` and the main menu
appears immediately. Config validation runs silently in the background; any
issues are shown in a panel before the menu loads.

### Screen map

```
Main Menu
├── Configure module
│   ├── Logging settings
│   ├── Mouse control settings
│   ├── Emergency stop settings
│   ├── Screenshot settings
│   ├── Set default code editor
│   └── Edit module configuration
├── Record macro            → select target window (step 1), then build a
│                             macro action by action and save
├── Run macro               → select and execute a saved macro; window is
│                             located automatically from the macro file
│                             (only shown when macros exist)
├── Manage macros           → view, edit, and delete saved macros
│                             (only shown when macros exist)
├── Manage schedules        → view, create, and remove Windows Scheduled Tasks
├── Storage info            → screenshot storage usage and log file stats
└── Exit
```

Each screen loops until the user navigates back. All config changes go
through `Test-ConfigValue` validation before saving — you can't accidentally
break the config via the UI.

---

### Macros folder

Macros are stored as JSON files at:

```
$env:APPDATA\LastWarAutoScreenshot\Macros\
```

The folder is created automatically by `Install-LWAS` (run via `scripts\Install-LWAS.ps1`)
and is also created on first macro save if it does not already exist.

**Filename convention:** `yyyyMMdd_HHmmss_<name>.json`

Example: `20260310_143022_OpenAllianceShop.json`

The `Run macro` menu option is only shown when `*.json` files exist in the
macros folder. The target window is located automatically at run time using
the processName and windowTitle stored inside the macro file. See
[MacroFormat.md](MacroFormat.md) for the full JSON schema and action type
reference.

---

### Bundled DLLs and `lib/VERSIONS.txt`

Spectre.Console is bundled (not installed from NuGet at runtime) to keep the
module self-contained.

| File | Purpose |
|------|---------|
| `lib/Spectre.Console.dll` | Core rendering library |
| `lib/test/Spectre.Console.Testing.dll` | `TestConsole` for Pester tests only |
| `lib/VERSIONS.txt` | Records the exact bundled versions |

**`VERSIONS.txt` format:**

```
Spectre.Console=0.54.0
Spectre.Console.Testing=0.54.0
TFM=net9.0
```

**Updating the bundled DLLs:**

1. Download the NuGet package for the target version:

   ```powershell
   Invoke-WebRequest `
       "https://www.nuget.org/api/v2/package/Spectre.Console/0.54.0" `
       -OutFile spectre.nupkg
   Rename-Item spectre.nupkg spectre.zip
   Expand-Archive spectre.zip -DestinationPath spectre_extracted
   ```

2. Copy `lib/net9.0/Spectre.Console.dll` from the extracted folder to
   `powershell-module/lib/Spectre.Console.dll`.

3. Repeat for `Spectre.Console.Testing`, placing the DLL in
   `powershell-module/lib/test/`.

4. Update `lib/VERSIONS.txt` with the new version strings.

5. Commit the updated DLLs (they are tracked in git, not ignored).

> Never auto-update the DLLs at runtime. The bundled version is the
> tested version; updates must go through a proper PR with full test runs.

---

### `IAnsiConsole` injection pattern (for contributors)

Every screen function accepts a `[Spectre.Console.IAnsiConsole]$Console`
parameter. The real console is the default; tests inject `TestConsole`.

**Adding a new screen:**

```powershell
function Show-MyScreen {
    [CmdletBinding()]
    param(
        [Spectre.Console.IAnsiConsole]$Console = (
            [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        )
    )

    $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Pick something:', @('Option A', 'Option B', 'Back')
    )
    $choice = $prompt.Show($Console)

    switch ($choice) {
        'Option A' { <# ... #> }
        'Option B' { <# ... #> }
        'Back'     { return $null }
    }
}
```

**Testing it:**

```powershell
BeforeAll {
    $testingDll = Join-Path $PSScriptRoot '..\..\lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

It 'Returns $null when user picks Back' {
    InModuleScope LastWarAutoScreenshot {
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Input.PushTextWithEnter('Back')
        $result = Show-MyScreen -Console $tc
        $result | Should -BeNullOrEmpty
    }
}
```

Assert on `$tc.Output` for rendered text, or mock downstream functions using
standard Pester `Mock`. All screen tests live in `Tests/ConsoleApp/`.

**`ConsoleAppBridge` helper methods:**

| Method | Returns | Notes |
|--------|---------|-------|
| `CreateConsole()` | `IAnsiConsole` | Live terminal |
| `CreateSelectionPrompt(title, choices[])` | `SelectionPrompt<string>` | Standard styling |
| `CreateTable(columns[])` | `Table` | Standard border |
| `CreatePanel(content, header)` | `Panel` | Standard styling |
