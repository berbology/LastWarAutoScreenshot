function Invoke-MacroSequence {
    <#
    .SYNOPSIS
        Executes a validated macro sequence against a target window.

    .DESCRIPTION
        Validates the supplied macro data, builds an action lookup table, optionally
        starts the emergency-stop monitor, then walks the sequence in order calling
        Invoke-MacroAction for each step. Halts on action failure or emergency stop.
        Always stops the emergency-stop monitor in a finally block.

    .PARAMETER MacroData
        The PSCustomObject representing the parsed macro (e.g. from ConvertFrom-Json
        or Get-MacroFile). Must pass Test-MacroFile validation before execution begins.

    .PARAMETER WindowHandle
        The window handle ([IntPtr]) of the target window. Passed through to
        Invoke-MacroAction for coordinate conversion.

    .PARAMETER Console
        An IAnsiConsole instance for progress output. Defaults to the production
        console created by ConsoleAppBridge. Inject a TestConsole in unit tests.

    .OUTPUTS
        PSCustomObject
        Properties: Success [bool], CompletedActions [int], TotalActions [int],
        SimilarityStop [bool], Message [string].
        CompletedActions counts only non-skipped successfully executed actions.
        SimilarityStop is $true when a Screenshot similarity threshold halted the macro;
        in this case Success is always $true (scroll end detected is the intended outcome).

    .EXAMPLE
        $handle = [IntPtr]::new($config.WindowHandleInt64)
        $result = Invoke-MacroSequence -MacroData $macroData -WindowHandle $handle
        if (-not $result.Success) { Write-Warning $result.Message }
        if ($result.SimilarityStop) { Write-Verbose 'Macro stopped due to similarity threshold.' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$MacroData,

        [Parameter(Mandatory)]
        [object]$WindowHandle,

        [Spectre.Console.IAnsiConsole]$Console = (
            [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
        )
    )

    # Validate macro before executing anything
    $validation = Test-MacroFile -MacroData $MacroData
    if (-not $validation.Valid) {
        $Console.Write([Spectre.Console.Markup]::new('[red]Macro validation failed:[/]')) | Out-Null
        foreach ($msg in $validation.Messages) {
            $Console.Write([Spectre.Console.Markup]::new("[red]  - $msg[/]")) | Out-Null
        }
        return [PSCustomObject]@{
            Success          = $false
            CompletedActions = 0
            TotalActions     = 0
            SimilarityStop   = $false
            Message          = 'Macro validation failed.'
        }
    }

    # Initialise screenshot context — shared across all actions and loop iterations
    # so index and previous-path tracking are continuous throughout execution.
    $screenshotContext = @{
        Index                   = 0
        MacroName               = $MacroData.metadata.name
        ActionName              = ''
        PreviousScreenshotPath  = $null
        ConsecutiveSimilarCount = 0
    }

    $similarityStop = $false

    # Build name -> action lookup for Loop resolution
    $actionLookup = @{}
    foreach ($action in $MacroData.sequence) {
        if ($action.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($action.name)) {
            $actionLookup[$action.name] = $action
        }
    }

    # Optionally start emergency-stop monitor
    try {
        $moduleConfig = Get-ModuleConfiguration
        if ($moduleConfig.EmergencyStop.AutoStart -eq $true) {
            Start-LWASEmergencyStopMonitor | Out-Null
        }
    } catch {
        Write-LastWarLog -Level Warning -FunctionName 'Invoke-MacroSequence' -Message "Could not read module configuration for emergency-stop auto-start: $_"
    }

    $completedActions = 0
    $totalActions     = $MacroData.sequence.Count
    $success          = $true
    $message          = 'Macro completed successfully.'

    try {
        $Console.Write([Spectre.Console.Markup]::new("[bold]Running macro: $($MacroData.metadata.name)[/] ($totalActions actions)`n")) | Out-Null

        $i = 0
        foreach ($action in $MacroData.sequence) {
            $i++

            $actionLabel = $action.type
            if ($action.PSObject.Properties['name'] -and -not [string]::IsNullOrEmpty($action.name)) {
                $actionLabel += " '$($action.name)'"
            }
            $Console.Write([Spectre.Console.Markup]::new("[blue]Executing step ${i} of ${totalActions}: $actionLabel[/]`n")) | Out-Null

            $result = Invoke-MacroAction -Action $action -WindowHandle $WindowHandle -ActionLookup $actionLookup -ScreenshotContext $screenshotContext

            if (-not $result.Success -and -not $result.Skipped) {
                $success = $false
                $message = "Macro halted at step ${i}: $($result.Message)"
                $Console.Write([Spectre.Console.Markup]::new("[red]Macro halted at step ${i}: $($result.Message)[/]`n")) | Out-Null
                break
            }

            if ($result.SimilarityStop -eq $true) {
                $Console.Write(
                    [Spectre.Console.Markup]::new("[yellow]Scroll end detected at step $i of $totalActions — macro completed (similarity threshold reached).`n[/]"))
                $completedActions++
                $similarityStop = $true
                break
            }

            if ($script:EmergencyStopRequested -or [LastWarAutoScreenshot.EmergencyStopMonitor]::StopRequested) {
                $script:EmergencyStopRequested = $true
                $success = $false
                $message = "Emergency stop triggered at step ${i}. Macro execution halted."
                $Console.Write([Spectre.Console.Markup]::new("[red]Emergency stop triggered at step ${i}. Macro execution halted.[/]`n")) | Out-Null
                break
            }

            if ($result.Skipped) {
                $Console.Write([Spectre.Console.Markup]::new("[grey]Step ${i} skipped ($($action.type) not yet implemented).[/]`n")) | Out-Null
            } else {
                $completedActions++
            }
        }
    } finally {
        Stop-LWASEmergencyStopMonitor
    }

    return [PSCustomObject]@{
        Success          = $success
        CompletedActions = $completedActions
        TotalActions     = $totalActions
        SimilarityStop   = $similarityStop
        Message          = $message
    }
}
