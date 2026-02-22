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
    }
}
