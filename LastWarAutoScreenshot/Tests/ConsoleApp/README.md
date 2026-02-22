# ConsoleApp Tests

This folder holds all **Phase 3** Pester tests for the console UI layer.

Each test file corresponds to a screen or helper function in `Private/ConsoleApp/`.

## Test Infrastructure

Tests use `Spectre.Console.Testing.TestConsole` for output capture:

```powershell
Add-Type -Path (Join-Path (Split-Path -Parent $PSScriptRoot) '..\lib\test\Spectre.Console.Testing.dll')
$testConsole = [Spectre.Console.Testing.TestConsole]::new()
```

Pass `$testConsole` to screen functions via the `-Console` parameter and assert on `$testConsole.Output`.

## Files (populated per screen)

| File | Screen / Function |
|------|------------------|
| `ConsoleAppBridge.Tests.ps1` | `[LastWarAutoScreenshot.ConsoleAppBridge]` type and methods |
