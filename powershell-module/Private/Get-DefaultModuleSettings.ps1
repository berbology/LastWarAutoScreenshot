function Get-DefaultModuleSettings {
    <#
    .SYNOPSIS
        Returns all default module configuration settings.

    .DESCRIPTION
        Provides a single source of truth for all default module settings (Logging,
        MouseControl, and EmergencyStop). These defaults are used by Get-ModuleConfiguration
        and Save-ModuleConfiguration to ensure consistency across the module.

    .OUTPUTS
        PSCustomObject
        Returns configuration object with properties:
        - Logging (PSCustomObject): Default logging backend settings
        - MouseControl (PSCustomObject): Default mouse control settings
        - EmergencyStop (PSCustomObject): Default emergency stop settings
        - Screenshots (PSCustomObject): Default screenshot storage settings

    .EXAMPLE
        $defaults = Get-DefaultModuleSettings
        # Use $defaults.MouseControl, $defaults.EmergencyStop, $defaults.Logging

    .NOTES
        This is the single source of truth for all default configuration values.
        Never hardcode defaults elsewhere in the module.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Compute default code editor: VSCode → VSCode Insiders → notepad.exe
    $codeEditorPath = "$env:SystemRoot\System32\notepad.exe"
    $vscodeInPath = Get-Command 'code.exe' -ErrorAction SilentlyContinue
    if ($vscodeInPath) {
        $codeEditorPath = $vscodeInPath.Source
    } else {
        $vscodeCandidates = @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
            "${env:ProgramFiles}\Microsoft VS Code\Code.exe",
            "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
        )
        $found = $false
        foreach ($candidate in $vscodeCandidates) {
            if (Test-Path -Path $candidate -PathType Leaf) {
                $codeEditorPath = $candidate
                $found = $true
                break
            }
        }
        if (-not $found) {
            $insidersInPath = Get-Command 'code-insiders.exe' -ErrorAction SilentlyContinue
            if ($insidersInPath) {
                $codeEditorPath = $insidersInPath.Source
            } else {
                $insidersCandidates = @(
                    "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Code - Insiders.exe",
                    "${env:ProgramFiles}\Microsoft VS Code Insiders\Code - Insiders.exe"
                )
                foreach ($candidate in $insidersCandidates) {
                    if (Test-Path -Path $candidate -PathType Leaf) {
                        $codeEditorPath = $candidate
                        break
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        Logging = [PSCustomObject]@{
            Backend         = 'File,EventLog'
            MinimumLogLevel = 'Info'
            FileBackend     = [PSCustomObject]@{
                MaxSizeMB        = 50
                MaxAgeDays       = 30
                MaxLogFileCount  = 500
            }
        }
        MouseControl = [PSCustomObject]@{
            EasingEnabled                  = $true
            OvershootEnabled               = $true
            OvershootFactor                = 0.1
            MicroPausesEnabled             = $true
            MicroPauseChance               = 0.2
            MinMicroPauseDurationMs        = 20
            MaxMicroPauseDurationMs        = 80
            JitterEnabled                  = $true
            JitterRadiusPx                 = 2
            BezierControlPointOffsetFactor = 0.3
            MinMovementDurationMs          = 200
            MaxMovementDurationMs          = 600
            MinClickDownDurationMs         = 50
            MaxClickDownDurationMs         = 150
            MinClickPreDelayMs             = 50
            MaxClickPreDelayMs             = 200
            MinClickPostDelayMs            = 100
            MaxClickPostDelayMs            = 300
            PathPointCount                 = 20
        }
        EmergencyStop = [PSCustomObject]@{
            AutoStart      = $true
            # 'Ctrl+Alt+Q' is the default emergency stop hotkey combination.
            # Users can reconfigure this to any key combination available on their keyboard.
            HotkeyKeyNames = 'Ctrl+Alt+Q'
            PollIntervalMs = 100
        }
        Screenshots = [PSCustomObject]@{
            StoragePath                    = 'C:\LastWarAutoScreenshot\Screenshots'
            MaxStorageGB                   = 2.0
            StorageWarningThresholdPercent = 90
            FileFormat                     = 'PNG'
            FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
            MaskColour                     = '0,0,0'
            SimilarityCheck                = [PSCustomObject]@{
                Enabled              = $false
                Threshold            = 0.98
                SampleCount          = 1000
                FullScan             = $false
                TolerancePerChannel  = 10
                Action               = 'StopLoop'
                ConsecutiveThreshold = 1
            }
        }
        CodeEditor = $codeEditorPath
        MacroExecution = [PSCustomObject]@{
            WindowRestoreDelayMs = 500
        }
    }
}

# ---------------------------------------------------------------------------
# Config validation schema - module-scoped constant, not inside the function.
# Each entry is keyed by "Section.Key" (or "Section.SubSection.Key") and
# describes the constraints used by Test-ConfigValue and the config screens.
# ---------------------------------------------------------------------------
$script:ConfigValidationSchema = @{

    # --- Logging ---
    'Logging.MinimumLogLevel'                     = @{
        Type          = 'stringEnum'
        AllowedValues = @('Verbose', 'Info', 'Warning', 'Error')
        Description   = 'Logging level'
        Nullable      = $false
    }
    'Logging.Backend'                             = @{
        Type          = 'stringEnum'
        AllowedValues = @('File', 'EventLog', 'File,EventLog')
        Description   = "Log target"
        Nullable      = $false
    }
    'Logging.FileBackend.MaxSizeMB'               = @{
        Type        = 'int'
        Min         = 1
        Max         = 10240
        Description = 'Log file rollover MB'
        Nullable    = $false
    }
    'Logging.FileBackend.MaxAgeDays'              = @{
        Type        = 'int'
        Min         = 1
        Max         = 3650
        Description = 'Log file retention days'
        Nullable    = $false
    }
    'Logging.FileBackend.MaxLogFileCount'         = @{
        Type        = 'int'
        Min         = 1
        Max         = 100000
        Description = 'Max log files to keep; once reached, the oldest is deleted when a new one is created'
        Nullable    = $false
    }

    # --- MouseControl bool toggles ---
    'MouseControl.EasingEnabled'                  = @{
        Type        = 'bool'
        Description = 'Apply ease-in/ease-out to mouse movement speed'
        Nullable    = $false
    }
    'MouseControl.OvershootEnabled'               = @{
        Type        = 'bool'
        Description = 'Cursor overshoots target then corrects'
        Nullable    = $false
    }
    'MouseControl.MicroPausesEnabled'             = @{
        Type        = 'bool'
        Description = 'Random micro-pauses inserted during movement'
        Nullable    = $false
    }
    'MouseControl.JitterEnabled'                  = @{
        Type        = 'bool'
        Description = 'Random pixel jitter applied to each Bezier path point'
        Nullable    = $false
    }

    # --- MouseControl numeric scalars ---
    'MouseControl.OvershootFactor'                = @{
        Type        = 'double'
        Min         = 0.0
        Max         = 1.0
        Description = 'Fraction of the last path step used as extra overshoot distance'
        Nullable    = $false
    }
    'MouseControl.MicroPauseChance'               = @{
        Type        = 'double'
        Min         = 0.0
        Max         = 1.0
        Description = 'Probability (0.0-1.0) of micro-pause after each movement step'
        Nullable    = $false
    }
    'MouseControl.JitterRadiusPx'                 = @{
        Type        = 'int'
        Min         = 0
        Max         = 20
        Description = 'Jitter max pixel radius applied to Bezier path points - 0 to disable'
        Nullable    = $false
    }
    'MouseControl.BezierControlPointOffsetFactor' = @{
        Type        = 'double'
        Min         = 0.0
        Max         = 2.0
        Description = 'Path length multiplier for positioning Bezier control point'
        Nullable    = $false
    }
    'MouseControl.PathPointCount'                 = @{
        Type        = 'int'
        Min         = 5
        Max         = 200
        Description = 'Base number of intermediate points on each Bezier movement path'
        Nullable    = $false
    }

    # --- MouseControl intArray ranges ---
    'MouseControl.MinMicroPauseDurationMs'        = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Minimum micro-pause delay duration in ms'
        Nullable    = $false
    }
    'MouseControl.MaxMicroPauseDurationMs'        = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Maximum micro-pause delay duration in ms'
        Nullable    = $false
    }
    'MouseControl.MinMovementDurationMs'          = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Minimum duration in ms for total mouse movement'
        Nullable    = $false
    }
    'MouseControl.MaxMovementDurationMs'          = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Maximum duration in ms for total mouse movement'
        Nullable    = $false
    }
    'MouseControl.MinClickDownDurationMs'     = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Minimum mouse-button hold duration in ms during click'
        Nullable    = $false
    }
    'MouseControl.MaxClickDownDurationMs'     = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Maximum mouse-button hold duration in ms during click'
        Nullable    = $false
    }
    'MouseControl.MinClickPreDelayMs'             = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Minimum delay in ms before each mouse click'
        Nullable    = $false
    }
    'MouseControl.MaxClickPreDelayMs'             = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Maximum delay in ms before each mouse click'
        Nullable    = $false
    }
    'MouseControl.MinClickPostDelayMs'            = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Minimum delay in ms after each mouse click'
        Nullable    = $false
    }
    'MouseControl.MaxClickPostDelayMs'            = @{
        Type        = 'int'
        Min         = 0
        Max         = 5000
        Description = 'Maximum delay in ms after each mouse click'
        Nullable    = $false
    }

    # --- EmergencyStop ---
    'EmergencyStop.AutoStart'                     = @{
        Type        = 'bool'
        Description = 'Whether the emergency stop monitor starts automatically when an automation sequence begins'
        Nullable    = $false
    }
    'EmergencyStop.PollIntervalMs'                = @{
        Type        = 'int'
        Min         = 10
        Max         = 5000
        Description = 'Interval in ms between emergency stop key-state polls'
        Nullable    = $false
    }
    # --- Screenshots ---
    'Screenshots.StoragePath'                     = @{
        Type        = 'string'
        Description = 'Screenshot save location'
        Nullable    = $true
    }
    'Screenshots.MaxStorageGB'                    = @{
        Type        = 'double'
        Min         = 0.1
        Max         = 2048.0
        Description = 'Max size of screenshot folder (GB)'
        Nullable    = $false
    }
    'Screenshots.StorageWarningThresholdPercent' = @{
        Type        = 'int'
        Min         = 1
        Max         = 99
        Description = 'Storage space used warning (%)'
        Nullable    = $false
    }
    'Screenshots.FileFormat'                     = @{
        Type          = 'stringEnum'
        AllowedValues = @('PNG')
        Description   = 'Screenshot file format. Only PNG is supported in this release'
        Nullable      = $false
    }
    'Screenshots.FilenamePattern'                = @{
        Type        = 'string'
        Description = 'Placeholders: {MacroName}, {ActionName}, {Timestamp}, {Date}, {Time}, {Index}'
        Nullable    = $false
    }
    'Screenshots.MaskColour'                     = @{
        Type        = 'string'
        Description = 'Colour used to fill screenshot black-out regions. Accepted formats: named colour (e.g. "red", "dark blue", "light green"), RGB triplet (e.g. "255,0,0"), or 6-character hex code (e.g. "FF0000"). Default: 0,0,0 (black)'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.Enabled'        = @{
        Type        = 'bool'
        Description = 'Consecutive duplicate screenshot detection'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.Threshold'      = @{
        Type        = 'double'
        Min         = 0.01
        Max         = 1.0
        Description = 'Duplicate trigger threshold (1.0 = 100% identical). Recommend: 0.98'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.SampleCount'    = @{
        Type        = 'int'
        Min         = 100
        Max         = 100000
        Description = 'Pixels per sample (Ignored when FullScan enabled)'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.FullScan'       = @{
        Type        = 'bool'
        Description = 'Compare every pixel. (More accurate but much slower)'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.TolerancePerChannel' = @{
        Type        = 'int'
        Min         = 0
        Max         = 255
        Description = 'Max per-channel (R/G/B) difference that counts as a matching pixel. 0 = exact match'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.Action'         = @{
        Type          = 'stringEnum'
        AllowedValues = @('StopLoop', 'StopMacro', 'Warn')
        Description   = 'Duplicate detected trigger action. (StopLoop|StopMacro|Warn)'
        Nullable      = $false
    }
    'Screenshots.SimilarityCheck.ConsecutiveThreshold' = @{
        Type        = 'int'
        Min         = 1
        Max         = 100
        Description = 'Consecutive duplicates required to trigger action. Higher value may reduce false positives'
        Nullable    = $false
    }

    # --- General ---
    'CodeEditor' = @{
        Type        = 'string'
        Description = 'Path to the executable used to open configuration files'
        Nullable    = $true
    }

    # --- MacroExecution ---
    'MacroExecution.WindowRestoreDelayMs' = @{
        Type        = 'int'
        Min         = 0
        Max         = 10000
        Description = 'Milliseconds to wait after restoring a minimised window before starting macro execution. Increase on slower machines if the first action fires before the window has fully rendered. Default: 500'
        Nullable    = $false
    }
}

