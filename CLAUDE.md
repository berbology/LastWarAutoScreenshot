# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerShell 7+ module (`LastWarAutoScreenshot`) that automates human-like mouse interactions and screen captures on Windows, targeting the game Last War: Survival. Uses Win32 P/Invoke via inline C# for mouse control and window enumeration, and Spectre.Console for the interactive console UI.

**Current status:** Phase 3 (Console App) complete. Phase 4 (Macro Recording) is next.

## Commands

```powershell
# Import the module
Import-Module .\LastWarAutoScreenshot\LastWarAutoScreenshot.psd1

# Launch the interactive app (entry point)
Start-LastWarAutoScreenshot

# Run full test suite (always run the full suite, never filter)
Invoke-Pester -Path .\LastWarAutoScreenshot\Tests -Output Detailed

# Run a single test file
Invoke-Pester -Path .\LastWarAutoScreenshot\Tests\ConsoleApp\Show-MainMenu.Tests.ps1 -Output Detailed
```

> **IMPORTANT:** Do NOT run tests yourself. Prompt the user to run them and report results back.

## Repository Structure

```
LastWarAutoScreenshot/
├── LastWarAutoScreenshot.psm1   # Module entry point: loads C# types, dot-sources all .ps1 files
├── LastWarAutoScreenshot.psd1   # Module manifest
├── src/                         # C# source files compiled at module load via Add-Type
│   ├── LogBackend.cs / FileLogBackend.cs
│   ├── WindowEnumerationAPI.cs
│   ├── MouseControlAPI.cs
│   └── ConsoleAppBridge.cs      # Spectre.Console factory helpers; references Spectre.Console.dll
├── lib/
│   ├── Spectre.Console.dll      # Bundled (not NuGet-installed at runtime), tracked in git
│   ├── VERSIONS.txt             # Records bundled DLL versions
│   └── test/
│       └── Spectre.Console.Testing.dll  # TestConsole for Pester tests only
├── Public/                      # Exported functions (dot-sourced by psm1)
├── Private/                     # Internal helpers (dot-sourced by psm1)
│   └── ConsoleApp/              # Screen functions: Show-MainMenu, Show-ConfigMenuScreen, etc.
├── Tests/                       # Pester test files (*.Tests.ps1)
│   └── ConsoleApp/              # Tests for all console screen functions
└── Docs/                        # Architecture and phase documentation
```

Config is stored at `$env:APPDATA\LastWarAutoScreenshot\ModuleConfig.json`. Macros will be stored in `Private/Macros/` (Phase 4, not yet implemented).

## Architecture

### Module Loading (`LastWarAutoScreenshot.psm1`)

On import, the psm1:
1. Verifies all C# source files and `lib/Spectre.Console.dll` exist
2. Checks whether the C# types are already loaded in the session (to survive `-Force` re-imports)
3. Compiles and loads C# types via `Add-Type`; `ConsoleAppBridge.cs` is compiled separately because it references `Spectre.Console.dll`
4. Dot-sources: `Private/LastWarAutoScreenshotHelpers.ps1` first, then all `Private/*.ps1`, then `Private/ConsoleApp/*.ps1`, then `Public/*.ps1`

### Console App (`IAnsiConsole` injection pattern)

Every screen function (`Show-*`) accepts `[Spectre.Console.IAnsiConsole]$Console`. In production, the default is `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`. In tests, inject `[Spectre.Console.Testing.TestConsole]`.

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
        'Pick something:', @('Option A', 'Back')
    )
    $choice = $prompt.Show($Console)
    switch ($choice) {
        'Back' { return $null }
    }
}
```

`ConsoleAppBridge` helper methods: `CreateConsole()`, `CreateSelectionPrompt(title, choices[])`, `CreateTable(columns[])`, `CreatePanel(content, header)`.

### Spectre.Console Markup Rules

Square brackets `[...]` are markup in Spectre.Console. **Always escape them with `[[...]]` in any string passed to a display method.** Use single brackets in string comparisons and variable assignments.

```powershell
$prompt.AddChoice('[[Back to main menu]]') | Out-Null  # display: [Back to main menu]
if ($selection -ieq '[Back to main menu]') { return }  # comparison uses single brackets
```

Always suppress return values from Spectre.Console methods with `| Out-Null`. Never use static `[Spectre.Console.AnsiConsole]::` calls in code that needs to be testable.

## PowerShell Conventions

- **Verb-Noun PascalCase** for all functions; use only approved PowerShell verbs
- **`[CmdletBinding()]`** must be the first line inside a function block
- **No aliases** in scripts (`Where-Object` not `?`, `ForEach-Object` not `%`, `Get-ChildItem` not `ls`)
- **PascalCase** for public variables and parameters; **camelCase** for private variables
- Never use PowerShell automatic variable names (`$Error`, `$Input`, `$Host`, `$foreach`, etc.)
- Opening braces on same line; 4-space indentation
- **Comment-based help** (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`) required on every function
- `Write-Verbose` for operational detail, `Write-Warning` for warnings, `Write-Error` / `throw` for errors; avoid `Write-Host`
- Never introduce whitespace before the terminating `'@` of a here-string

## Testing (Pester v5.7.1)

- Test files: `*.Tests.ps1`, placed in `Tests/` or `Tests/ConsoleApp/`
- Import the module in `BeforeAll` at the top level using the manifest path, never dot-source module scripts directly:
  ```powershell
  BeforeAll {
      $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
      Import-Module $moduleManifest -Force
  }
  ```
- Load `Spectre.Console.Testing.dll` in `BeforeAll` for console tests:
  ```powershell
  $testingDll = Join-Path $PSScriptRoot '..\..\lib\test\Spectre.Console.Testing.dll'
  Add-Type -Path $testingDll
  ```
- Use `InModuleScope LastWarAutoScreenshot { }` inside `It`, `Context`, or `BeforeAll/BeforeEach` blocks — **not** as a wrapper around multiple lifecycle blocks
- **`$script:` scope warning:** `$script:` inside `InModuleScope` resolves to the module's script scope, not the test file's scope. Never read a `$script:` variable inside `InModuleScope` that was set outside it. Reset module-scope `$script:` variables inside `InModuleScope` in `BeforeEach`/`AfterEach`.
- Use `Should -Invoke` (not the deprecated `Assert-MockCalled`)
- Use `-TestCases` / `-ForEach` for data-driven tests
- Full test suite must pass (all files, no filters) before any task is marked complete. Check and report total test count vs. the known baseline.

## Critical Workflow Rules

- **Never refactor** unless explicitly asked. Only make the minimal change required.
- **Never delete comments** or commented-out code without asking first.
- **Use British English** in all responses, comments, and code.
- If a fix needs a refactor, ask before proceeding.
- When asked to fix an error, give ONE clear solution.
- Update `Docs/` files in the same PR as code changes when relevant (see `update-docs-on-code-change.instructions.md`).
- The bundled Spectre.Console DLLs are tracked in git. Never auto-update them at runtime. Updates must go through a proper PR with full test runs.
