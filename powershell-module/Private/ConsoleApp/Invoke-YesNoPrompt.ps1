function Invoke-YesNoPrompt {
    <#
    .SYNOPSIS
        Displays a yes/no selection prompt and returns a boolean result.

    .DESCRIPTION
        Presents a Spectre.Console SelectionPrompt with 'Yes' and 'No' choices.
        Returns $true when the user selects 'Yes', $false for 'No'.

    .PARAMETER Console
        The Spectre.Console IAnsiConsole instance used for all rendering and input.

    .PARAMETER Message
        The prompt message displayed to the user.

    .OUTPUTS
        System.Boolean

    .EXAMPLE
        $addMask = Invoke-YesNoPrompt -Console $Console -Message 'Add a black-out region?'
        if ($addMask) { ... }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $prompt = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt(
        $Message, @('Yes', 'No')
    )
    $choice = $prompt.Show($Console)
    return $choice -eq 'Yes'
}
