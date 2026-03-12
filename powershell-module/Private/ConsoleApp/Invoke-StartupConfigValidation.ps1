function Invoke-StartupConfigValidation {
    <#
    .SYNOPSIS
        Validates the saved module configuration at application startup and reports
        any issues to the user via Spectre.Console panels.

    .DESCRIPTION
        Performs the following checks in order:

        1. Calls Get-ModuleConfiguration to load the saved configuration.
           - If the file does not exist or is empty, Get-ModuleConfiguration creates and
             returns a default configuration - this is always valid so the function
             returns immediately with HasErrors=$false.
           - If the file contains invalid JSON, the underlying exception is caught here
             and an error Panel is written to $Console; HasErrors=$true is returned.

        2. If the file loaded successfully, iterates every key in
           $script:ConfigValidationSchema and calls Test-ConfigValue for each one.
           Collects all failures.

        3. If any failures are found, writes a warning Panel listing each failing key
           and its validation message, then waits for the user to press Enter.

        The function NEVER aborts startup.  All issues are advisory - the module
        operates on defaults for any invalid values until the user corrects them via
        'Configure Module'.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for writing panels and waiting
        for user acknowledgement.  Inject a TestConsole in Pester tests.

    .OUTPUTS
        PSCustomObject
        Returns an object with:
          HasErrors  [bool]    - $true if any validation issue was found.
          Messages   [string[]] - Array of human-readable issue descriptions
                                  (empty array when HasErrors is $false).
          UserAction [string]  - User's action choice: 'Continue', 'ConfigureModule', or 'Exit'.
                                 Only set when HasErrors is $true.

    .EXAMPLE
        $result = Invoke-StartupConfigValidation -Console $console
        if ($result.HasErrors) {
            Write-Verbose "Startup found $($result.Messages.Count) config issue(s)."
        }

    .NOTES
        Invalid JSON path:
          Get-ModuleConfiguration throws a System.ArgumentException (or similar) when
          the JSON cannot be parsed.  This function catches all exceptions from that
          call and maps them to the HasErrors=$true path.

        Fresh install path:
          Get-ModuleConfiguration creates a default-only config when no file exists.
          All default values satisfy the schema, so this function returns HasErrors=$false
          with UserAction='Continue' immediately without writing any output to $Console.

        User action selection:
          When validation errors or warnings are found, a selection prompt is displayed
          with two options: 'Configure Module' and 'Exit'. The user's choice is returned
          in the UserAction property:
            - 'ConfigureModule': User wants to configure the module
            - 'Exit': User wants to exit the application
            - 'Continue': No issues found (normal flow)

        TestConsole note:
          When using Spectre.Console.Testing.TestConsole, all Write() calls are captured
          in $testConsole.Output.  The selection prompt will use $testConsole.Input to
          read the user's choice - tests must queue an input key or option before calling
          this function if a validation error or warning is expected. Use
          $testConsole.Input.PushText() or similar methods to simulate user selections.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    $messages = [System.Collections.Generic.List[string]]::new()
    $hasErrors = $false
    $config    = $null

    # ── Step 1: Load configuration ────────────────────────────────────────────
    try {
        $config = Get-ModuleConfiguration
    }
    catch {
        $hasErrors = $true
        $errorMsg  = "Configuration file contains invalid JSON. Default values will be used. Please reconfigure via 'Configure Module'."
        $messages.Add($errorMsg)

        Write-LastWarLog -Level Warning -Message $errorMsg -FunctionName 'Invoke-StartupConfigValidation'

        $errorPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel($errorMsg, '[red]Configuration Error[/]')
        $Console.Write($errorPanel)

        # Show selection prompt for user action
        $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            "What would you like to do?",
            @("Configure Module", "Exit")
        )
        $choice = $prompt.Show($Console)

        $userAction = if ($choice -eq "Exit") { "Exit" } else { "ConfigureModule" }

        return [PSCustomObject]@{
            HasErrors  = $hasErrors
            Messages   = $messages.ToArray()
            UserAction = $userAction
        }
    }

    # ── Step 2: Validate each key in the schema ───────────────────────────────
    $failureMessages = [System.Collections.Generic.List[string]]::new()

    foreach ($key in $script:ConfigValidationSchema.Keys) {
        $parts = $key -split '\.'
        $value = $null

        try {
            if ($parts.Count -eq 2) {
                $value = $config."$($parts[0])"."$($parts[1])"
            }
            elseif ($parts.Count -eq 3) {
                $value = $config."$($parts[0])"."$($parts[1])"."$($parts[2])"
            }
        }
        catch {
            # Property navigation failed - skip this key; it will show as null in validation
        }

        $validationResult = Test-ConfigValue -Key $key -Value $value
        if (-not $validationResult.Valid) {
            $failureMessages.Add("  $key`: $($validationResult.Message)")
        }
    }

    # ── Step 3: Report failures ───────────────────────────────────────────────
    if ($failureMessages.Count -gt 0) {
        $hasErrors = $true
        foreach ($msg in $failureMessages) { $messages.Add($msg) }

        $messageBody = "The following configuration values are invalid and will use defaults:`n" +
                       ($failureMessages -join "`n")

        Write-LastWarLog -Level Warning `
            -Message "Startup configuration validation found $($failureMessages.Count) issue(s)." `
            -FunctionName 'Invoke-StartupConfigValidation' `
            -Context ($failureMessages -join '; ')

        $warningPanel = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel($messageBody, '[yellow]Configuration Warnings[/]')
        $Console.Write($warningPanel)

        # Show selection prompt for user action
        $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
            "What would you like to do?",
            @("Configure Module", "Exit")
        )
        $choice = $prompt.Show($Console)

        $userAction = if ($choice -eq "Exit") { "Exit" } else { "ConfigureModule" }
    }
    else {
        $userAction = "Continue"
    }

    return [PSCustomObject]@{
        HasErrors  = $hasErrors
        Messages   = $messages.ToArray()
        UserAction = $userAction
    }
}

