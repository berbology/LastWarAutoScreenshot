# Tests

Pester v5 test suite for the Last War AutoScript module. All tests must pass
before any phase is marked complete.

## Running the tests

```powershell
# Full suite from the repo root (always run this)
Invoke-Pester -Path .\powershell-module\Tests -Output Detailed

# Single file — for debugging a specific failure only
Invoke-Pester -Path .\powershell-module\Tests\ConsoleApp\Show-MainMenu.Tests.ps1 -Output Detailed
```

## Structure

```
Tests/
├── ConsoleApp/               # Pester tests for Private/ConsoleApp/ screen functions
│   └── README.md             # Setup guide for the console UI test harness
├── *.Tests.ps1               # Tests for Public/ and Private/ functions
├── *_Integration.Tests.ps1   # Integration tests (hit real system resources)
└── *_TypeDefinition.Tests.ps1 # C# type-definition tests (verify Add-Type output)
```

### Filename suffixes

| Suffix | Meaning |
|--------|---------|
| _(none)_ | Unit tests — all external dependencies are mocked |
| `_Integration` | Integration tests — interact with real file system, Windows APIs, or other system resources. Some require Administrator privileges or a live game window. |
| `_TypeDefinition` | Verify that C# types compiled by `Add-Type` have the expected properties, methods, and signatures. These tests catch issues where a C# source change silently breaks the PowerShell interface. |

## Test conventions

- Import the module via the manifest in a top-level `BeforeAll`, never via
  dot-sourcing individual scripts:

  ```powershell
  BeforeAll {
      $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
      Import-Module $moduleManifest -Force
  }
  ```

- Use `InModuleScope LastWarAutoScreenshot { }` inside `It`, `Context`, or
  `BeforeAll`/`BeforeEach` blocks to access private functions.
- Use `Should -Invoke` (not the deprecated `Assert-MockCalled`).

## ConsoleApp tests

The `ConsoleApp/` subfolder contains tests for all screen functions. See
[`ConsoleApp/README.md`](ConsoleApp/README.md) for the `TestConsole` setup
pattern and a complete file-to-function mapping.
