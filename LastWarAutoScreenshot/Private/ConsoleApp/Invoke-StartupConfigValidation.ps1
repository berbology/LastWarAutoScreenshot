function Invoke-StartupConfigValidation {
    <#
    .SYNOPSIS
        Validates the saved module configuration at application startup and reports
        any issues to the user via Spectre.Console panels.

    .DESCRIPTION
        Performs the following checks in order:

        1. Calls Get-ModuleConfiguration to load the saved configuration.
           - If the file does not exist or is empty, Get-ModuleConfiguration creates and
             returns a default configuration — this is always valid so the function
             returns immediately with HasErrors=$false.
           - If the file contains invalid JSON, the underlying exception is caught here
             and an error Panel is written to $Console; HasErrors=$true is returned.

        2. If the file loaded successfully, iterates every key in
           $script:ConfigValidationSchema and calls Test-ConfigValue for each one.
           Collects all failures.

        3. If any failures are found, writes a warning Panel listing each failing key
           and its validation message, then waits for the user to press Enter.

        The function NEVER aborts startup.  All issues are advisory — the module
        operates on defaults for any invalid values until the user corrects them via
        'Configure Module'.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for writing panels and waiting
        for user acknowledgement.  Inject a TestConsole in Pester tests.

    .OUTPUTS
        PSCustomObject
        Returns an object with:
          HasErrors [bool]    — $true if any validation issue was found.
          Messages  [string[]] — Array of human-readable issue descriptions
                                 (empty array when HasErrors is $false).

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
          immediately without writing any output to $Console.

        TestConsole note:
          When using Spectre.Console.Testing.TestConsole, all Write() calls are captured
          in $testConsole.Output.  The 'Press Enter to continue' step reads one key via
          $Console.Input.ReadKey($true) — tests must push a key before calling this
          function if a validation error or warning is expected.
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

        # Wait for user acknowledgement
        $Console.Write([Spectre.Console.Markup]::new("[grey]Press [[Enter]] to continue...[/]`n"))
        $Console.Input.ReadKey($true) | Out-Null

        return [PSCustomObject]@{
            HasErrors = $hasErrors
            Messages  = $messages.ToArray()
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
            # Property navigation failed — skip this key; it will show as null in validation
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

        # Wait for user acknowledgement
        $Console.Write([Spectre.Console.Markup]::new("[grey]Press [[Enter]] to continue...[/]`n"))
        $Console.Input.ReadKey($true) | Out-Null
    }

    return [PSCustomObject]@{
        HasErrors = $hasErrors
        Messages  = $messages.ToArray()
    }
}
