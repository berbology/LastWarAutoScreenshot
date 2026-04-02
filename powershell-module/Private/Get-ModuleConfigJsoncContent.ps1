function Get-ModuleConfigJsoncContent {
    <#
    .SYNOPSIS
        Serialises a module configuration object to a JSONC string with embedded comments.

    .DESCRIPTION
        Converts the supplied configuration object to JSON and injects JSONC-compatible
        comment blocks before each major section so that users editing the file manually
        can quickly understand the purpose and valid range of every setting.

        Comments are derived from the ConfigValidationSchema defined in
        Get-DefaultModuleSettings.ps1 and therefore always stay in sync with validation.

    .PARAMETER Config
        The full configuration PSCustomObject to serialise.

    .OUTPUTS
        System.String
        Returns the JSONC content as a single string ready to be written to disk.

    .EXAMPLE
        $jsonc = Get-ModuleConfigJsoncContent -Config $configObject
        Set-Content -Path $path -Value $jsonc -Encoding UTF8
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$Config
    )

    # Serialise to standard JSON first (2-space indent, depth 5)
    $json = $Config | ConvertTo-Json -Depth 5

    # ---------------------------------------------------------------------------
    # Helper: build a comment block string for a named section.
    # Each $lines entry is a plain string that becomes a "// " comment line.
    # ---------------------------------------------------------------------------
    function buildCommentBlock {
        param(
            [string[]]$Lines
        )
        ($Lines | ForEach-Object { "  // $_" }) -join "`n"
    }

    # ---------------------------------------------------------------------------
    # Section comment blocks
    # ---------------------------------------------------------------------------
    $loggingComment = buildCommentBlock @(
        '--------------------------------------------------------------------------',
        'Logging',
        '  Backend          : Log target.',
        '                     Allowed values : File | EventLog | File,EventLog',
        '  MinimumLogLevel  : Minimum severity to record.',
        '                     Allowed values : Verbose | Info | Warning | Error',
        '  FileBackend',
        '    MaxSizeMB      : Roll over to a new log file after this many MB. Range : 1-10240',
        '    MaxAgeDays     : Delete log files older than this many days.     Range : 1-3650',
        '    MaxLogFileCount: Maximum number of log files to keep.            Range : 1-100000',
        '--------------------------------------------------------------------------'
    )

    $mouseControlComment = buildCommentBlock @(
        '--------------------------------------------------------------------------',
        'MouseControl  (human-like movement simulation)',
        '  EasingEnabled                 : Apply ease-in/ease-out to movement speed',
        '  OvershootEnabled              : Cursor overshoots target then self-corrects',
        '  OvershootFactor               : Extra overshoot as a fraction of the last path step. Range : 0.0-1.0',
        '  MicroPausesEnabled            : Insert random micro-pauses during movement',
        '  MicroPauseChance              : Probability of a micro-pause after each step.         Range : 0.0-1.0',
        '  MinMicroPauseDurationMs       : Shortest micro-pause.                                 Range : 0-5000 ms',
        '  MaxMicroPauseDurationMs       : Longest micro-pause.                                  Range : 0-5000 ms',
        '  JitterEnabled                 : Apply random pixel jitter to Bezier path points',
        '  JitterRadiusPx                : Jitter radius (0 = disabled).                         Range : 0-20 px',
        '  BezierControlPointOffsetFactor: Path-length multiplier for the Bezier control point.  Range : 0.0-2.0',
        '  MinMovementDurationMs         : Shortest total mouse movement.                        Range : 0-5000 ms',
        '  MaxMovementDurationMs         : Longest total mouse movement.                         Range : 0-5000 ms',
        '  MinClickDownDurationMs        : Shortest mouse-button hold during a click.            Range : 0-5000 ms',
        '  MaxClickDownDurationMs        : Longest mouse-button hold during a click.             Range : 0-5000 ms',
        '  MinClickPreDelayMs            : Shortest delay before each click.                     Range : 0-5000 ms',
        '  MaxClickPreDelayMs            : Longest delay before each click.                      Range : 0-5000 ms',
        '  MinClickPostDelayMs           : Shortest delay after each click.                      Range : 0-5000 ms',
        '  MaxClickPostDelayMs           : Longest delay after each click.                       Range : 0-5000 ms',
        '  PathPointCount                : Number of intermediate Bezier path points.            Range : 5-200',
        '--------------------------------------------------------------------------'
    )

    $emergencyStopComment = buildCommentBlock @(
        '--------------------------------------------------------------------------',
        'EmergencyStop',
        '  AutoStart      : Start the monitor automatically when a macro begins',
        '  HotkeyKeyNames : Key combination that aborts automation (e.g. Ctrl+Alt+Q).',
        '                   Any combination of Ctrl, Alt, Shift plus a letter or function key is accepted.',
        '  PollIntervalMs : How often the hotkey state is checked.  Range : 10-5000 ms',
        '--------------------------------------------------------------------------'
    )

    $screenshotsComment = buildCommentBlock @(
        '--------------------------------------------------------------------------',
        'Screenshots',
        '  StoragePath                        : Directory where screenshots are saved',
        '  MaxStorageGB                       : Maximum folder size; oldest files deleted when exceeded.  Range : 0.1-2048 GB',
        '  StorageWarningThresholdPercent     : Warn when usage exceeds this % of MaxStorageGB.          Range : 1-99',
        '  FileFormat                         : Image format.  Allowed values : PNG',
        '  FilenamePattern                    : Filename template.',
        '                                       Placeholders : {MacroName} {ActionName} {Timestamp} {Date} {Time} {Index}',
        '  MaskColour                         : Fill colour for blacked-out regions.',
        '                                       Accepted : named colour (e.g. red, dark blue), RGB triplet (e.g. 255,0,0),',
        '                                                  or 6-char hex (e.g. FF0000).  Default : 0,0,0 (black)',
        '  SimilarityCheck',
        '    Enabled              : Enable consecutive duplicate screenshot detection',
        '    Threshold            : Similarity needed to count as a duplicate (1.0 = 100% identical). Range : 0.01-1.0',
        '    SampleCount          : Random pixels sampled per comparison (ignored when FullScan is true). Range : 100-100000',
        '    FullScan             : Compare every pixel (more accurate but slower)',
        '    TolerancePerChannel  : Maximum per-channel (R/G/B) difference that counts as matching (0 = exact). Range : 0-255',
        '    Action               : Action taken when a duplicate is detected. Allowed values : StopLoop | StopMacro | Warn',
        '    ConsecutiveThreshold : Consecutive duplicates required to trigger Action. Range : 1-100',
        '--------------------------------------------------------------------------'
    )

    $codeEditorComment = buildCommentBlock @(
        '--------------------------------------------------------------------------',
        'CodeEditor: Path to the executable used to open configuration files.',
        '            Examples : C:\Windows\System32\notepad.exe',
        '                       C:\Users\<name>\AppData\Local\Programs\Microsoft VS Code\Code.exe',
        '--------------------------------------------------------------------------'
    )

    $macroExecutionComment = buildCommentBlock @(
        '--------------------------------------------------------------------------',
        'MacroExecution',
        '  WindowRestoreDelayMs : Milliseconds to wait after restoring a minimised window',
        '                         before macro execution begins.',
        '                         Increase on slower machines if the first action fires',
        '                         before the window has fully rendered.  Range : 0-10000 ms',
        '--------------------------------------------------------------------------'
    )

    # ---------------------------------------------------------------------------
    # Inject comment blocks into the JSON string.
    # ConvertTo-Json emits property lines as:  "  "Key": value" (2-space indent).
    # We match the exact line start so only top-level keys are targeted.
    # ---------------------------------------------------------------------------
    $sectionInjections = [ordered]@{
        '  "Logging"'        = $loggingComment
        '  "MouseControl"'   = $mouseControlComment
        '  "EmergencyStop"'  = $emergencyStopComment
        '  "Screenshots"'    = $screenshotsComment
        '  "CodeEditor"'     = $codeEditorComment
        '  "MacroExecution"' = $macroExecutionComment
    }

    $lines = $json -split "`n"
    $outputLines = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        $trimmed = $line.TrimEnd()

        # Check whether this line starts a top-level section that needs a comment block injected above it.
        # $key includes the 2-space indent (e.g. '  "Logging"'), so StartsWith only matches top-level keys.
        foreach ($key in $sectionInjections.Keys) {
            if ($line.StartsWith($key)) {
                $outputLines.Add('')
                $outputLines.Add($sectionInjections[$key])
                break
            }
        }

        $outputLines.Add($trimmed)
    }

    return $outputLines -join "`n"
}
