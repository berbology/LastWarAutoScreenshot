# lib

Bundled DLL dependencies for the `LastWarAutoScreenshot` module.

---

## Contents

| File | Purpose |
|------|---------|
| `Spectre.Console.dll` | Core rendering library used by all screen functions |
| `test/Spectre.Console.Testing.dll` | `TestConsole` for Pester tests only; not included in release builds |
| `VERSIONS.txt` | Records the exact bundled versions and target framework |

Current versions (from `VERSIONS.txt`):

```
Spectre.Console=0.54.0
Spectre.Console.Testing=0.54.0
TFM=net9.0
```

---

## Why DLLs are tracked in git

The module is self-contained — it must work immediately after install without
a NuGet restore or internet connection. Bundling the DLLs in git guarantees
that the exact tested version is always present, regardless of the user's
environment.

---

## Updating the bundled DLLs

DLL updates must go through a pull request. Steps:

1. Download the target NuGet packages and extract the `net9.0` DLLs.
2. Replace `lib/Spectre.Console.dll` and `lib/test/Spectre.Console.Testing.dll`.
3. Update `lib/VERSIONS.txt` with the new version strings and TFM.
4. Run the full Pester test suite (`Invoke-Pester -Path .\powershell-module\Tests -Output Detailed`).
5. All tests must pass before the PR is merged.

See [Docs/ConsoleApp.md](../Docs/ConsoleApp.md) for detailed extraction steps.
