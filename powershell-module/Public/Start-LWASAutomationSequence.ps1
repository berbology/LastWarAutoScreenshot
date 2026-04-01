function Invoke-IsIconic {
    <#
    .SYNOPSIS
        Thin wrapper around the Win32 IsIconic API call, used to allow mocking in tests.
    #>
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle
    )
    return [LastWarAutoScreenshot.WindowEnumerationAPI]::IsIconic($WindowHandle)
}

function Start-LWASAutomationSequence {
    <#
    .SYNOPSIS
        Executes a named macro against one or more target windows.

    .DESCRIPTION
        Accepts window objects from Get-LWASTargetWindow via the pipeline. For each window:
          1. Validates the window handle is still live.
          2. Reads the module configuration.
          3. Loads the named macro via Get-LWASMacro.
          4. Validates SAS tokens for every UploadScreenshots action in the macro; if a
             token is absent or within the five-minute safety buffer it is refreshed
             automatically using Update-LWASSASToken. Macro execution is aborted if a
             referenced upload profile cannot be found or token renewal fails.
          5. Restores the window if it is minimised, then waits for the configured delay.
          6. Activates the window (brings it to the foreground) via Set-WindowActive.
          7. Executes the macro via Invoke-MacroSequence (which manages the emergency stop
             monitor lifecycle internally).
          8. Writes a result object to the pipeline.

        Non-terminating errors (Write-Error) are emitted when a window handle is invalid,
        a macro cannot be loaded, an upload profile is missing, or SAS token renewal fails;
        pipeline processing continues for subsequent window objects.

    .PARAMETER WindowObject
        Mandatory. A window object as returned by Get-LWASTargetWindow. Must have WindowHandle,
        ProcessName, WindowTitle, and WindowState properties.

    .PARAMETER MacroName
        Mandatory. The name of the macro to execute (matches the Name property of the macro,
        not the filename).

    .OUTPUTS
        PSCustomObject
        One result object per processed window with properties:
          Success      [bool]   — whether the macro completed without error
          MacroName    [string] — the macro name that was requested
          WindowTitle  [string] — the window title the macro ran against
          Message      [string] — success or failure detail

    .EXAMPLE
        # Scheduled-task use: find one instance of the game and run a macro
        Get-LWASTargetWindow -ProcessName 'lastwar.exe' -First |
            Start-LWASAutomationSequence -MacroName 'DailyLogin'

    .EXAMPLE
        # Multi-instance use: run the same macro against every matching window
        Get-LWASTargetWindow -ProcessName 'lastwar.exe' |
            Start-LWASAutomationSequence -MacroName 'DailyLogin'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$WindowObject,

        [Parameter(Mandatory)]
        [string]$MacroName
    )

    process {
        # 1. Validate window handle
        $isValid = Test-WindowHandleValid -WindowHandle $WindowObject.WindowHandle
        if (-not $isValid) {
            $msg = "Window '$($WindowObject.WindowTitle)' is no longer valid."
            Write-Error $msg
            Write-Output ([PSCustomObject]@{
                Success     = $false
                MacroName   = $MacroName
                WindowTitle = $WindowObject.WindowTitle
                Message     = $msg
            })
            return
        }

        # 2. Read config
        $config = Get-ModuleConfiguration

        # 3. Load macro
        $macroResults = @(Get-LWASMacro -Name $MacroName -ErrorAction SilentlyContinue)
        if ($macroResults.Count -eq 0) {
            $msg = "Macro '$MacroName' could not be loaded."
            Write-Error $msg
            Write-Output ([PSCustomObject]@{
                Success     = $false
                MacroName   = $MacroName
                WindowTitle = $WindowObject.WindowTitle
                Message     = $msg
            })
            return
        }
        $macroItem = $macroResults[0]

        # Build the data object that Invoke-MacroSequence expects
        $macroData = [PSCustomObject]@{
            version      = $macroItem.Version
            targetWindow = $macroItem.TargetWindow
            metadata     = $macroItem.Metadata
            sequence     = $macroItem.Sequence
        }

        # 4. SAS token preflight — validate/refresh tokens for all UploadScreenshots actions
        $uploadActions = @($macroItem.Sequence | Where-Object { $_.type -eq 'UploadScreenshots' })
        $checkedProfiles = @{}
        foreach ($uploadAction in $uploadActions) {
            $profileName = $uploadAction.uploadProfileName
            if ($checkedProfiles.ContainsKey($profileName)) {
                continue
            }
            $checkedProfiles[$profileName] = $true

            $uploadProfile = Get-UploadProfile -Name $profileName
            if ($null -eq $uploadProfile) {
                $msg = "Upload profile '$profileName' referenced in macro '$MacroName' was not found."
                Write-Error $msg
                Write-Output ([PSCustomObject]@{
                    Success     = $false
                    MacroName   = $MacroName
                    WindowTitle = $WindowObject.WindowTitle
                    Message     = $msg
                })
                return
            }

            $envVarName = $uploadProfile.sasTokenEnvVar
            $currentToken = [Environment]::GetEnvironmentVariable($envVarName) `
                ?? [Environment]::GetEnvironmentVariable($envVarName, [EnvironmentVariableTarget]::User) `
                ?? [Environment]::GetEnvironmentVariable($envVarName, [EnvironmentVariableTarget]::Machine)

            if (-not (Test-LWASSASTokenIsValid -SasToken ([string]($currentToken ?? '')))) {
                Write-LastWarLog -Level Info `
                    -Message "SAS token for profile '$profileName' (env var '$envVarName') is absent or expired — refreshing before macro execution." `
                    -FunctionName 'Start-LWASAutomationSequence'

                $updateResult = Update-LWASSASToken -Name $envVarName -UploadProfile $profileName
                if (-not $updateResult) {
                    $msg = "Failed to refresh SAS token for upload profile '$profileName'. Cannot proceed with macro '$MacroName'."
                    Write-Error $msg
                    Write-Output ([PSCustomObject]@{
                        Success     = $false
                        MacroName   = $MacroName
                        WindowTitle = $WindowObject.WindowTitle
                        Message     = $msg
                    })
                    return
                }
            }
        }

        # 5. Restore if minimised
        if (Invoke-IsIconic -WindowHandle $WindowObject.WindowHandle) {
            Set-WindowState -WindowHandle $WindowObject.WindowHandle -State 'Restore' | Out-Null
            Write-LastWarLog -Level Info `
                -Message "Restored minimised window '$($WindowObject.WindowTitle)' before macro execution." `
                -FunctionName 'Start-LWASAutomationSequence'
            Start-Sleep -Milliseconds $config.MacroExecution.WindowRestoreDelayMs
        }

        # 6. Activate window (bring to foreground)
        Set-WindowActive -WindowHandle $WindowObject.WindowHandle | Out-Null

        # 7. Execute macro (emergency stop lifecycle is managed inside Invoke-MacroSequence)
        $success = $true
        $message = 'Macro completed successfully.'
        try {
            $execResult = Invoke-MacroSequence -MacroData $macroData -WindowHandle $WindowObject.WindowHandle
            $success = $execResult.Success
            $message = $execResult.Message
        } catch {
            $success = $false
            $message = "Macro execution failed: $_"
            Write-Error $message
        }

        Write-Output ([PSCustomObject]@{
            Success     = $success
            MacroName   = $MacroName
            WindowTitle = $WindowObject.WindowTitle
            Message     = $message
        })
    }
}
