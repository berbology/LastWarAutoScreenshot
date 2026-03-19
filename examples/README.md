# Examples

## `ModuleConfig-example.jsonc`

An annotated reference showing every module configuration key at its default
value, grouped by category (`MouseControl`, `EmergencyStop`, `Screenshots`,
`Logging`, `MacroExecution`, `CodeEditor`).

**Important:** `.jsonc` files use JSON with Comments syntax. The real
configuration file (`ModuleConfig.json`) does **not** support comments and
cannot be replaced with this file directly. The real file is created
automatically at:

```
%APPDATA%\LastWarAutoScreenshot\ModuleConfig.json
```

on first run, with all defaults applied. Use the interactive console app
(**Configure module** menu) to change settings — no manual JSON editing is
required.

For the full configuration reference including accepted value ranges and
behaviour notes, see [Docs/Configuration.md](../powershell-module/Docs/Configuration.md).
