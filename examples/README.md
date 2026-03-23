# Examples

## `ModuleConfig-example.jsonc`

An annotated reference showing every module configuration key at its default
value, grouped by category (`MouseControl`, `EmergencyStop`, `Screenshots`,
`Logging`, `MacroExecution`, `CodeEditor`).

**Important:** Both files use JSON with Comments (`.jsonc`) syntax, which
PowerShell's `ConvertFrom-Json` cmdlet (v7+) handles natively. The example
file documents all available keys; the real configuration file is created
automatically at:

```
%APPDATA%\LastWarAutoScreenshot\ModuleConfig.jsonc
```

on first run, with all defaults applied. Use the interactive console app
(**Configure module** menu) to change settings — no manual JSON editing is
required.

For the full configuration reference including accepted value ranges and
behaviour notes, see [Docs/Configuration.md](../powershell-module/Docs/Configuration.md).
