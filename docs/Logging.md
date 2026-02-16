# Logging Standard for LastWarAutoScreenshot

## Where and How Logging Occurs

- **File Logging:** All error and event logs are written to `LastWarAutoClickScreenshot.log` in the module directory. Log entries are in JSON format for easy parsing and analysis.
- **Windows Event Logging:** Critical errors and diagnostic events may also be written to the Windows Event Log (requires admin privileges). Viewable in Windows Event Viewer.
- **Console Output:** User-facing errors and warnings are displayed in plain text for immediate feedback.


## Logging Levels and Configuration

- **Verbosity Levels:**
  - `Info`: Standard operations and successful events.
  - `Warning`: Recoverable issues, unexpected but non-fatal conditions.
  - `Error`: Failures, exceptions, or unrecoverable problems.
- **Debug Mode:**
  - When run with `-Debug` or `-Verbose`, all operations and internal state changes are logged for troubleshooting.
  - Debug mode includes all relevant variables and context in error log events.
- **Configuration:**
  - Verbosity level is configurable via command-line parameters or the GUI "Logging" tab.
  - **Logging backend selection is controlled by the module configuration file** (`ModuleConfig.json`).
  - The `Logging.Backend` property determines which backends are used. Supported values: `File`, `EventLog`, or both (comma-separated).

### Example: ModuleConfig.json

```json
{
  "Logging": {
    "Backend": "File,EventLog"
  }
}
```

- To log only to file:
  ```json
  { "Logging": { "Backend": "File" } }
  ```
- To log only to Windows Event Log:
  ```json
  { "Logging": { "Backend": "EventLog" } }
  ```
- If the config or property is missing/invalid, file logging is used by default.

## What Gets Logged

- **All operations** (in debug/verbose mode): Function calls, parameters, and state changes.
- **Errors and exceptions:** Always logged with full context, stack trace, and error type.
- **Warnings:** Unexpected but non-fatal issues, such as recoverable API failures.
- **User actions:** Emergency stops, configuration changes, and critical user-triggered events.
- **Mid-sequence failures:** All failures during automation are logged with full context; retry logic is also logged.
- **Window crashes/closes:** Detected and logged; sequence aborts gracefully with error event.
- **Upload/storage failures:** Exponential backoff and retry attempts are logged.
- **Emergency stops:** All emergency stops (hotkey or mouse gesture) are logged for audit purposes.

## Standard Logging Format


# Logging Standard for LastWarAutoScreenshot


## Purpose


All log entries must include the following fields:

| Field           | Description                                      | Example                        |
|-----------------|--------------------------------------------------|--------------------------------|
| Timestamp       | UTC time of the event (ISO 8601)                 | 2026-02-15T14:23:01Z           |
| FunctionName    | Name of the function where the log is generated  | Get-EnumeratedWindows          |
| ErrorType       | Type/category of error (e.g., Exception, Warning)| Exception                      |
| Message         | Error or event message                           | Failed to enumerate windows     |
| Context         | Key context info (parameters, state, etc.)       | WindowHandle=0x001A02          |
| StackTrace      | (If error) Call stack at the time of error       | ...                            |


### Example Log Entry (JSON)

```json
{
  "Timestamp": "2026-02-15T14:23:01Z",
  "FunctionName": "Get-EnumeratedWindows",
  "ErrorType": "Exception",
  "Message": "Failed to enumerate windows",
  "Context": "WindowHandle=0x001A02",
  "StackTrace": "at Get-EnumeratedWindows..."
}
```


### Example Log Entry (Plain Text)

```
```


## Implementation Guidance

- Use the logging helper function for all error/event logs.
- Always include all required fields.
- Prefer JSON format for logs written to file or external systems.
- Use plain text for console/user-facing logs if preferred.
- See the table above for what is logged at each level.


## Updating the Logging Helper

- Add inline comments to clarify field usage for future maintainers.


## References

- See README.md for a summary and quick reference.
- For implementation, see `src/LastWarAutoClickScreenshot/private/Write-LastWarLog.ps1`.
