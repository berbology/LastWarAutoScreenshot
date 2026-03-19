# Tests

Pester v5 test suite for the `LastWarAutoScreenshot` module.

---

## Structure

```
Tests/
├── ConsoleApp/   — screen function tests; see ConsoleApp/README.md for setup
└── *.Tests.ps1   — all other module tests
```

Tests in the root `Tests/` folder cover public functions, private helpers, C# type definitions, and integration scenarios. Tests in `ConsoleApp/` cover the interactive console UI layer.

---

## Running the suite

```powershell
# Full suite (always run this before committing)
Invoke-Pester -Path .\powershell-module\Tests -Output Detailed

# Single file (debugging only)
Invoke-Pester -Path .\powershell-module\Tests\ConsoleApp\Show-MainMenu.Tests.ps1 -Output Detailed
```

All tests must pass with zero failures. Never filter by tag or file as part of a normal workflow.

---

## Filename suffixes

| Suffix | Meaning |
|--------|---------|
| *(none)* | Standard unit test — runs without any external dependencies |
| `_Integration` | Requires a live system resource (e.g. Windows Event Log, file system, real windows). May be skipped in restricted CI environments. |
| `_TypeDefinition` | Verifies that a C# type compiled via `Add-Type` has the expected members and signatures |

---

## ConsoleApp tests

Screen function tests live in `ConsoleApp/` and use `Spectre.Console.Testing.TestConsole` for terminal injection. See [`ConsoleApp/README.md`](ConsoleApp/README.md) for the test harness setup and a file-to-screen-function mapping table.
