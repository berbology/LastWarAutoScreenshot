# powershell-module

Source tree for the `LastWarAutoScreenshot` PowerShell 7+ module.

---

## Folder overview

| Folder | Contents |
|--------|----------|
| `src/` | C# source files compiled at module load via `Add-Type` (Win32 P/Invoke, Spectre.Console bridge) |
| `lib/` | Bundled DLLs (`Spectre.Console.dll`, `Spectre.Console.Testing.dll`) tracked in git; see [`lib/README.md`](lib/README.md) |
| `Public/` | Exported module functions dot-sourced by the psm1 |
| `Private/` | Internal helpers dot-sourced by the psm1; `Private/ConsoleApp/` contains all screen functions |
| `Tests/` | Pester v5 test suite; see [`Tests/README.md`](Tests/README.md) |
| `Docs/` | Architecture and reference documentation for contributors and users |

The module entry point is `LastWarAutoScreenshot.psm1`. The manifest is `LastWarAutoScreenshot.psd1`.

---

## Import from source

```powershell
Import-Module .\powershell-module\LastWarAutoScreenshot.psd1 -Force
```

Use `-Force` whenever you make changes to module files and need to reload.

---

## Run the test suite

```powershell
Invoke-Pester -Path .\powershell-module\Tests -Output Detailed
```

Always run the full suite — never filter by file or tag unless debugging a specific failure. All tests must pass before any change is committed.

---

For a complete contributor reference see [`Docs/Developer.md`](Docs/Developer.md).
