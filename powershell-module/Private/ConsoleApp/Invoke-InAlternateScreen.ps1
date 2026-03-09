function Invoke-InAlternateScreen {
    <#
    .SYNOPSIS
        Runs a script block inside an alternate terminal screen buffer.

    .DESCRIPTION
        Thin PowerShell wrapper over [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen.
        Keeping the C# boundary behind a PowerShell function means tests can mock this function,
        allowing the script block to execute entirely in PowerShell (preserving module-private function
        scope) without crossing the C#/PowerShell delegate boundary.

        The action is wrapped in its own inner closure before being passed to C# as [System.Action].
        This inner closure captures $Action and $Console via GetNewClosure() and calls & $Action $Console,
        so the outer scriptblock never uses GetNewClosure() and retains its module session state binding.
        Without this pattern, GetNewClosure() on the caller's scriptblock would strip the module's
        session state, causing private function resolution to fail inside the closure.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance to use.

    .PARAMETER Action
        The script block to run inside the alternate buffer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console,

        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    [LastWarAutoScreenshot.ConsoleAppBridge]::RunInAlternateScreen(
        $Console,
        [System.Action]{ & $Action $Console }.GetNewClosure()
    )
}
