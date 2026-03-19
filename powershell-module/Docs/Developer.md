# Developer Guide

Reference for contributors and anyone working on the module internals.

For the user-facing guide see [UserGuide.md](UserGuide.md). For the project task
list and architecture decisions see [ProjectPlan.md](ProjectPlan.md).

---

## Contents

- [Getting started](#getting-started)
- [Repository structure](#repository-structure)
- [Module loading](#module-loading)
- [Installation](#installation)
- [Uninstallation](#uninstallation)
- [Creating a release](#creating-a-release)
- [Running the test suite](#running-the-test-suite)
- [Console app — IAnsiConsole injection](#console-app--iansiConsole-injection)
- [Adding a new screen](#adding-a-new-screen)
- [ConsoleAppBridge reference](#consoleappbridge-reference)
- [Spectre.Console markup rules](#spectreconsole-markup-rules)
- [Invoke-MouseDragClick](#invoke-mousedragclick)
- [Further reading](#further-reading)

---

## Getting started

### 1. Clone the repository

```powershell
git clone https://github.com/berbology/LastWarAutoScreenshot.git
cd LastWarAutoScreenshot
```

### 2. Import the module

```powershell
Import-Module .\powershell-module\LastWarAutoScreenshot.psd1 -Force
```

Use `-Force` whenever you make changes to module files and need to reload.

### 3. Launch the app

```powershell
Start-LWASConsole
```

### 4. Run the test suite

```powershell
Invoke-Pester -Path .\powershell-module\Tests -Output Detailed
```

Always run the full suite — never filter by file or tag unless debugging a
specific failure. All tests must pass before any change is committed.

### 5. Optional — install to PSModulePath

To use `Import-Module LastWarAutoScreenshot` (without specifying a path) from
any terminal, install the module in an elevated PowerShell session:

```powershell
Install-LWAS
```

Use `-Force` to overwrite an existing installation without prompting:

```powershell
Install-LWAS -Force
```

The module is installed to:

```
$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\{version}\
```

---

## Repository structure

```
powershell-module/
├── LastWarAutoScreenshot.psm1   # Module entry point: loads C# types,
│                                # dot-sources all .ps1 files
├── LastWarAutoScreenshot.psd1   # Module manifest
├── src/                         # C# source files compiled at module load
│   ├── LogBackend.cs
│   ├── FileLogBackend.cs
│   ├── WindowEnumerationAPI.cs
│   ├── MouseControlAPI.cs
│   └── ConsoleAppBridge.cs      # Spectre.Console factory helpers;
│                                # references Spectre.Console.dll
├── lib/
│   ├── Spectre.Console.dll      # Bundled (not NuGet); tracked in git
│   ├── VERSIONS.txt             # Records bundled DLL versions
│   └── test/
│       └── Spectre.Console.Testing.dll  # TestConsole for Pester only
├── Public/                      # Exported functions (dot-sourced by psm1)
├── Private/                     # Internal helpers (dot-sourced by psm1)
│   └── ConsoleApp/              # Screen functions: Show-MainMenu, etc.
├── Tests/                       # Pester test files (*.Tests.ps1)
│   └── ConsoleApp/              # Tests for all console screen functions
└── Docs/                        # Architecture and phase documentation
```

Config is stored at `$env:APPDATA\LastWarAutoScreenshot\ModuleConfig.json`.
Macros are stored at `$env:APPDATA\LastWarAutoScreenshot\Macros\`.

---

## Module loading

On import, `LastWarAutoScreenshot.psm1`:

1. Verifies all C# source files and `lib/Spectre.Console.dll` exist.
2. Checks whether the C# types are already loaded (to survive `-Force`
   re-imports without duplicate-type errors).
3. Compiles and loads C# types via `Add-Type`. `ConsoleAppBridge.cs` is
   compiled separately because it references `Spectre.Console.dll`.
4. Dot-sources in order:
   - `Private/LastWarAutoScreenshotHelpers.ps1`
   - All other `Private/*.ps1`
   - `Private/ConsoleApp/*.ps1`
   - `Public/*.ps1`

---

## Installation

### From a GitHub Release zip

1. Download and extract `LastWarAutoScreenshot-v{version}.zip`.
2. Open an elevated PowerShell terminal and run:

   ```powershell
   .\scripts\Install-LWAS.ps1
   ```

   The script self-elevates automatically if the current session is not already
   elevated (re-launches via `Start-Process pwsh -Verb RunAs`).

3. After installation, import the module from any session:

   ```powershell
   Import-Module LastWarAutoScreenshot
   ```

The module is installed to:

```
$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\{version}\
```

This follows the PowerShell module versioning convention (same as `Install-Module`)
and allows side-by-side versions.

### From the repo (development)

```powershell
Import-Module .\powershell-module\LastWarAutoScreenshot.psd1 -Force
```

To also register the module to PSModulePath (optional):

```powershell
Install-LWAS
```

Use `-Force` to overwrite an existing installation without prompting:

```powershell
Install-LWAS -Force
```

---

## Uninstallation

```powershell
# Remove the module and event log source; prompt before removing AppData
.\scripts\Uninstall-LWAS.ps1

# Remove everything including AppData directory without prompting
.\scripts\Uninstall-LWAS.ps1 -RemoveAppData
```

After uninstalling, start a new PowerShell session to ensure no module
assemblies remain loaded in memory.

---

## Creating a release

**Pre-requisites:** all Pester tests passing; psd1 metadata reviewed.

```powershell
.\scripts\New-LWASRelease.ps1 -Version '1.1.0' -ReleaseNotes 'Description of changes.'
```

The script:

1. Validates the version string (semver `x.y.z`).
2. Updates `ModuleVersion` and `ReleaseNotes` in the psd1.
3. Runs the full Pester suite (abort on failure).
4. Creates the release zip at `releases\LastWarAutoScreenshot-v{version}.zip`.
5. Prints a post-release checklist:
   - Commit the psd1 change
   - `git tag v{version}`
   - `git push && git push origin v{version}`
   - Upload the zip to GitHub Releases

The `releases/` directory is in `.gitignore` and is created at runtime.

---

## Running the test suite

Tests use [Pester v5](https://pester.dev). Always run the full suite — never
filter by file or tag unless debugging a specific failure.

```powershell
# Full suite from the repo root
Invoke-Pester -Path .\powershell-module\Tests -Output Detailed

# Single file (debugging only)
Invoke-Pester -Path .\powershell-module\Tests\ConsoleApp\Show-MainMenu.Tests.ps1 -Output Detailed
```

All tests must pass with 0 failures before any phase is marked complete.

See [`Tests/ConsoleApp/README.md`](../Tests/ConsoleApp/README.md) for notes
on the console UI test harness and `TestConsole` setup.

---

## Console app — IAnsiConsole injection

Every screen function (`Show-*`) accepts a
`[Spectre.Console.IAnsiConsole]$Console` parameter. In production the default
is `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`. In tests,
inject `[Spectre.Console.Testing.TestConsole]` instead.

This pattern keeps all screen functions fully unit-testable without touching
a real terminal.

**Test example:**

```powershell
BeforeAll {
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) `
        'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force

    $testingDll = Join-Path $PSScriptRoot '..\..\lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}

It 'renders the main menu' {
    InModuleScope LastWarAutoScreenshot {
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Input.PushTextWithEnter('Exit')
        Show-MainMenu -Console $tc
        $tc.Output | Should -Match 'Exit'
    }
}
```

---

## Adding a new screen

1. Create `Show-MyScreen.ps1` in `Private/ConsoleApp/`.
2. Give it a `[Spectre.Console.IAnsiConsole]$Console` parameter defaulting
   to `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`.
3. Add a corresponding `Show-MyScreen.Tests.ps1` in `Tests/ConsoleApp/`.
4. Dispatch to it from `Show-MainMenu.ps1` or `Show-ConfigMenuScreen.ps1`.

Minimal template:

```powershell
function Show-MyScreen {
    [CmdletBinding()]
    param(
        [Spectre.Console.IAnsiConsole]$Console = (
            [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        )
    )
    $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        'Pick something:', @('Option A', 'Back')
    )
    $choice = $prompt.Show($Console)
    switch ($choice) {
        'Back' { return $null }
    }
}
```

See [ConsoleApp.md](ConsoleApp.md) for the full screen map and dispatch
details.

---

## ConsoleAppBridge reference

`[LastWarAutoScreenshot.ConsoleAppBridge]` (compiled from `src/ConsoleAppBridge.cs`)
provides factory helpers so PowerShell screen functions never call static
`[Spectre.Console.AnsiConsole]::` methods directly (which cannot be
intercepted in tests).

| Method | Returns | Notes |
|--------|---------|-------|
| `CreateConsole()` | `IAnsiConsole` | Production terminal instance |
| `CreateSelectionPrompt(title, choices[])` | `SelectionPrompt<string>` | Use `.Show($Console)` to display |
| `CreateTable(columns[])` | `Table` | Add rows, then pass to `$Console.Write(...)` |
| `CreatePanel(content, header)` | `Panel` | Pass to `$Console.Write(...)` |

Always suppress return values from Spectre.Console methods with `| Out-Null`.

The bundled DLLs in `lib/` are tracked in git. Never auto-update them at
runtime. Updates must go through a proper PR with full test runs and a note
in `lib/VERSIONS.txt`.

---

## Spectre.Console markup rules

Square brackets `[...]` are markup in Spectre.Console. **Always escape them
with `[[...]]` in any string passed to a display method.** Use single brackets
in string comparisons and variable assignments.

```powershell
# Display: [Back to main menu]
$prompt.AddChoice('[[Back to main menu]]') | Out-Null

# Comparison uses single brackets
if ($selection -ieq '[Back to main menu]') { return }
```

Full markup reference: <https://spectreconsole.net/markup>

---

## Invoke-MouseDragClick

Private helper that implements a drag-click action using the existing mouse
control infrastructure.

**Execution order:**

1. Move to the start position via a Bézier path.
2. Check emergency stop.
3. Pre-click delay (random within `ClickPreDelayRangeMs`).
4. Send `MOUSEEVENTF_LEFTDOWN`.
5. Hold delay (random within `ClickDownDurationRangeMs`).
6. Check emergency stop.
7. Drag to the end position via a second Bézier path (button held).
8. Send `MOUSEEVENTF_LEFTUP` (always, even on error — wrapped in `finally`).
9. Post-click delay (random within `MinClickPostDelayMs`–`MaxClickPostDelayMs`).

```powershell
# Called internally by Invoke-MacroAction for DragClick sequence actions.
# Direct usage example (absolute screen coordinates):
$result = Invoke-MouseDragClick -StartX 400 -StartY 600 -EndX 400 -EndY 200
if (-not $result.Success) {
    Write-Warning "Drag-click failed: $($result.Message)"
}
```

Returns `[PSCustomObject]@{Success=[bool]; Message=[string]}`.

The `MOUSEEVENTF_LEFTUP` send is in a `finally` block to ensure the mouse
button is always released, even on an unhandled exception or emergency stop —
a stuck button would otherwise make the system unusable.

---

## Further reading

| Doc | What it covers |
|-----|----------------|
| [ConsoleApp.md](ConsoleApp.md) | Entry point, screen navigation, macro folder, DLL versioning, `IAnsiConsole` injection |
| [Configuration.md](Configuration.md) | All config keys with types, defaults, and examples |
| [MacroFormat.md](MacroFormat.md) | Full JSON macro schema, action type reference, validation rules, annotated examples |
| [WindowManagement.md](WindowManagement.md) | Window state functions, monitoring, emergency stop |
| [Logging.md](Logging.md) | Log backends, levels, troubleshooting, Event Log registration |
| [ProjectPlan.md](ProjectPlan.md) | Full phase-by-phase task list and architecture decisions |
| [Spectre.Console docs](https://spectreconsole.net/) | Official library documentation |
