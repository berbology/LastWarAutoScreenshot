# powershell-module

PowerShell 7+ module source for Last War AutoScript. This directory contains
the full module implementation, test suite, and documentation.

## Folder structure

```
powershell-module/
├── LastWarAutoScreenshot.psm1   # Module entry point — loads C# types, dot-sources all .ps1 files
├── LastWarAutoScreenshot.psd1   # Module manifest (version, exports, dependencies)
├── src/                         # C# source files compiled at module load via Add-Type
│   ├── LogBackend.cs
│   ├── FileLogBackend.cs
│   ├── WindowEnumerationAPI.cs
│   ├── MouseControlAPI.cs
│   └── ConsoleAppBridge.cs      # Spectre.Console factory helpers
├── lib/                         # Bundled DLLs tracked in git — see lib/README.md
│   ├── Spectre.Console.dll
│   ├── VERSIONS.txt
│   └── test/
│       └── Spectre.Console.Testing.dll
├── Public/                      # Exported functions (dot-sourced by psm1)
├── Private/                     # Internal helpers (dot-sourced by psm1)
│   ├── ConsoleApp/              # Screen functions — see Private/ConsoleApp/README.md
│   └── Macros/                  # Saved macro JSON files (created at runtime)
├── Tests/                       # Pester test suite — see Tests/README.md
│   └── ConsoleApp/              # Console UI tests — see Tests/ConsoleApp/README.md
└── Docs/                        # Architecture and reference documentation
```

## Importing from source

```powershell
Import-Module .\powershell-module\LastWarAutoScreenshot.psd1 -Force
```

Use `-Force` whenever you make changes to module files and need to reload.

## Running the test suite

```powershell
Invoke-Pester -Path .\powershell-module\Tests -Output Detailed
```

Always run the full suite — never filter by file or tag unless debugging a
specific failure. See [Tests/README.md](Tests/README.md) for details.

## Documentation

Full architecture and reference docs are in [`Docs/`](Docs/). Start with:

- [Developer Guide](Docs/Developer.md) — getting started, module loading,
  installation, adding new screens
- [ConsoleApp.md](Docs/ConsoleApp.md) — screen map, IAnsiConsole injection
- [Configuration.md](Docs/Configuration.md) — all config keys with defaults
