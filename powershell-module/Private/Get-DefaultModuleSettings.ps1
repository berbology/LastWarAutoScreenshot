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

    return [PSCustomObject]@{
        Logging = [PSCustomObject]@{
            Backend         = 'File,EventLog'
            MinimumLogLevel = 'Info'
            FileBackend     = [PSCustomObject]@{
                MaxSizeMB          = 50
                MaxFileCount       = 50
                MaxAgeDays         = 30
                RetentionFileCount = 500
            }
        }
        MouseControl = [PSCustomObject]@{
            EasingEnabled                  = $true
            OvershootEnabled               = $true
            OvershootFactor                = 0.1
            MicroPausesEnabled             = $true
            MicroPauseChance               = 0.2
            MicroPauseDurationRangeMs      = @(20, 80)
            JitterEnabled                  = $true
            JitterRadiusPx                 = 2
            BezierControlPointOffsetFactor = 0.3
            MovementDurationRangeMs        = @(200, 600)
            ClickDownDurationRangeMs       = @(50, 150)
            ClickPreDelayRangeMs           = @(50, 200)
            ClickPostDelayRangeMs          = @(100, 300)
            PathPointCount                 = 20
        }
        EmergencyStop = [PSCustomObject]@{
            AutoStart                  = $true
            # 17 = Ctrl (0x11), 16 = Shift (0x10), 220 = '#' on UK layout (0xDC)
            HotkeyVKeyCodes            = @(17, 16, 220)
            PollIntervalMs             = 100
            # Hold both mouse buttons (VK_LBUTTON 0x01, VK_RBUTTON 0x02) for this duration to trigger stop.
            # VK codes for mouse buttons are fixed and keyboard-layout-independent.
            MouseGestureEnabled        = $true
            MouseGestureHoldDurationMs = 3000
        }
        Screenshots = [PSCustomObject]@{
            StoragePath                    = 'C:\LastWarAutoScreenshot\Screenshots'
            MaxStorageGB                   = 2.0
            StorageWarningThresholdPercent = 90
            FileFormat                     = 'PNG'
            FilenamePattern                = '{MacroName}_{ActionName}_{Timestamp}_{Index}'
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
        Description   = 'Minimum log level for all logging backends'
        Nullable      = $false
    }
    'Logging.Backend'                             = @{
        Type          = 'stringEnum'
        AllowedValues = @('File', 'EventLog', 'File,EventLog')
        Description   = "Active logging backend(s); use 'File', 'EventLog', or 'File,EventLog'"
        Nullable      = $false
    }
    'Logging.FileBackend.MaxSizeMB'               = @{
        Type        = 'int'
        Min         = 1
        Max         = 10240
        Description = 'Maximum size in MB per log file before rollover is triggered (1-10240)'
        Nullable    = $false
    }
    'Logging.FileBackend.MaxFileCount'            = @{
        Type        = 'int'
        Min         = 1
        Max         = 10000
        Description = 'Maximum number of log files to retain per rollover cycle (1-10000)'
        Nullable    = $false
    }
    'Logging.FileBackend.MaxAgeDays'              = @{
        Type        = 'int'
        Min         = 1
        Max         = 3650
        Description = 'Maximum age in days of log files before they are purged (1-3650)'
        Nullable    = $false
    }
    'Logging.FileBackend.RetentionFileCount'      = @{
        Type        = 'int'
        Min         = 1
        Max         = 100000
        Description = 'Total number of log files to keep across all rollover archives (1-100000)'
        Nullable    = $false
    }

    # --- MouseControl bool toggles ---
    'MouseControl.EasingEnabled'                  = @{
        Type        = 'bool'
        Description = 'Whether ease-in/ease-out is applied to mouse movement speed'
        Nullable    = $false
    }
    'MouseControl.OvershootEnabled'               = @{
        Type        = 'bool'
        Description = 'Whether the cursor overshoots the target then corrects back'
        Nullable    = $false
    }
    'MouseControl.MicroPausesEnabled'             = @{
        Type        = 'bool'
        Description = 'Whether random micro-pauses are inserted during movement'
        Nullable    = $false
    }
    'MouseControl.JitterEnabled'                  = @{
        Type        = 'bool'
        Description = 'Whether random pixel jitter is applied to each Bezier path point'
        Nullable    = $false
    }

    # --- MouseControl numeric scalars ---
    'MouseControl.OvershootFactor'                = @{
        Type        = 'double'
        Min         = 0.0
        Max         = 1.0
        Description = 'Fraction of the last path step used as extra overshoot distance (0.0-1.0)'
        Nullable    = $false
    }
    'MouseControl.MicroPauseChance'               = @{
        Type        = 'double'
        Min         = 0.0
        Max         = 1.0
        Description = 'Probability (0.0-1.0) of inserting a micro-pause after each movement step'
        Nullable    = $false
    }
    'MouseControl.JitterRadiusPx'                 = @{
        Type        = 'int'
        Min         = 0
        Max         = 20
        Description = 'Maximum pixel radius of jitter applied to Bezier path points - 0 disables jitter (0-20)'
        Nullable    = $false
    }
    'MouseControl.BezierControlPointOffsetFactor' = @{
        Type        = 'double'
        Min         = 0.0
        Max         = 2.0
        Description = 'Multiplier applied to path length when positioning the Bezier control point (0.0-2.0)'
        Nullable    = $false
    }
    'MouseControl.PathPointCount'                 = @{
        Type        = 'int'
        Min         = 5
        Max         = 200
        Description = 'Base number of intermediate points on each Bezier movement path (5-200)'
        Nullable    = $false
    }

    # --- MouseControl intArray ranges ---
    'MouseControl.MicroPauseDurationRangeMs'      = @{
        Type        = 'intArray'
        Min         = 0
        Max         = 5000
        Description = 'Duration range [min, max] in ms for micro-pause delays (each element 0-5000, min <= max)'
        Nullable    = $false
    }
    'MouseControl.MovementDurationRangeMs'        = @{
        Type        = 'intArray'
        Min         = 0
        Max         = 5000
        Description = 'Duration range [min, max] in ms for total mouse movement (each element 0-5000, min <= max)'
        Nullable    = $false
    }
    'MouseControl.ClickDownDurationRangeMs'       = @{
        Type        = 'intArray'
        Min         = 0
        Max         = 5000
        Description = 'Duration range [min, max] in ms for mouse-button hold during click (each element 0-5000, min ≤ max)'
        Nullable    = $false
    }
    'MouseControl.ClickPreDelayRangeMs'           = @{
        Type        = 'intArray'
        Min         = 0
        Max         = 5000
        Description = 'Duration range [min, max] in ms for delay before each mouse click (each element 0-5000, min ≤ max)'
        Nullable    = $false
    }
    'MouseControl.ClickPostDelayRangeMs'          = @{
        Type        = 'intArray'
        Min         = 0
        Max         = 5000
        Description = 'Duration range [min, max] in ms for delay after each mouse click (each element 0-5000, min ≤ max)'
        Nullable    = $false
    }

    # --- EmergencyStop ---
    'EmergencyStop.AutoStart'                     = @{
        Type        = 'bool'
        Description = 'Whether the emergency stop monitor starts automatically when an automation sequence begins'
        Nullable    = $false
    }
    'EmergencyStop.MouseGestureEnabled'           = @{
        Type        = 'bool'
        Description = 'Whether the two-button mouse gesture is enabled as an alternate emergency stop trigger'
        Nullable    = $false
    }
    'EmergencyStop.PollIntervalMs'                = @{
        Type        = 'int'
        Min         = 10
        Max         = 5000
        Description = 'Interval in ms between emergency stop key-state polls (10-5000)'
        Nullable    = $false
    }
    'EmergencyStop.MouseGestureHoldDurationMs'    = @{
        Type        = 'int'
        Min         = 500
        Max         = 30000
        Description = 'Duration in ms both mouse buttons must be held to trigger emergency stop (500-30000)'
        Nullable    = $false
    }

    # --- Screenshots ---
    'Screenshots.StoragePath'                     = @{
        Type        = 'string'
        Description = 'Folder path where screenshots are stored'
        Nullable    = $true
    }
    'Screenshots.MaxStorageGB'                    = @{
        Type        = 'double'
        Min         = 0.1
        Max         = 2048.0
        Description = 'Maximum storage allocated to screenshots in GB (0.1-2048.0)'
        Nullable    = $false
    }
    'Screenshots.StorageWarningThresholdPercent' = @{
        Type        = 'int'
        Min         = 1
        Max         = 99
        Description = 'Warn when screenshot storage usage exceeds this percentage of the configured MaxStorageGB limit'
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
        Description = 'Filename pattern. Placeholders: {MacroName}, {ActionName}, {Timestamp}, {Date}, {Time}, {Index}. Resolved filename must not exceed 200 characters'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.Enabled'        = @{
        Type        = 'bool'
        Description = 'Enable similarity detection to automatically stop macro execution when consecutive screenshots match (scroll-end detection)'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.Threshold'      = @{
        Type        = 'double'
        Min         = 0.01
        Max         = 1.0
        Description = 'Similarity ratio required to trigger the configured Action (0.0 to 1.0, where 1.0 = 100% identical). Recommended: 0.98'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.SampleCount'    = @{
        Type        = 'int'
        Min         = 100
        Max         = 100000
        Description = 'Number of pixels sampled for comparison. Ignored when FullScan is true'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.FullScan'       = @{
        Type        = 'bool'
        Description = 'Compare every pixel instead of a sample. More accurate but slower for large screenshots'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.TolerancePerChannel' = @{
        Type        = 'int'
        Min         = 0
        Max         = 255
        Description = 'Maximum per-channel (R/G/B) difference that still counts as a matching pixel. 0 = exact match required'
        Nullable    = $false
    }
    'Screenshots.SimilarityCheck.Action'         = @{
        Type          = 'stringEnum'
        AllowedValues = @('StopLoop', 'StopMacro', 'Warn')
        Description   = 'Action when threshold is reached. StopLoop exits the current loop and continues the parent sequence. StopMacro halts the entire macro. Warn logs and continues'
        Nullable      = $false
    }
    'Screenshots.SimilarityCheck.ConsecutiveThreshold' = @{
        Type        = 'int'
        Min         = 1
        Max         = 100
        Description = 'Number of consecutive screenshots that must each exceed the similarity threshold before the configured Action fires. 1 = trigger on first match (default). Use a higher value to avoid false positives on briefly static content'
        Nullable    = $false
    }
}

