---
applyTo: '**/*.ps1,**/*.psm1'
description: 'Spectre.Console PowerShell integration best practices for rich console applications, markup syntax, and TestConsole testing patterns'
---

# Spectre.Console Best Practices for PowerShell

This guide provides essential rules and patterns for using Spectre.Console in PowerShell projects, with emphasis on markup safety, testing practices, and avoiding common pitfalls.

## Official Documentation

Refer to these authoritative resources for complete guides:

- **Main Documentation:** <https://spectreconsole.net/console>
- **Markup Reference:** <https://spectreconsole.net/console/reference/markup-reference>
- **Escaping Markup Guide:** <https://spectreconsole.net/console/how-to/escaping-markup>
- **Testing Console Output:** <https://spectreconsole.net/console/how-to/testing-console-output>
- **SelectionPrompt:** <https://spectreconsole.net/console/prompts/selection-prompt>
- **TextPrompt:** <https://spectreconsole.net/console/prompts/text-prompt>

## Critical Rule: Escape Square Brackets in Markup

**CRITICAL:** Spectre.Console uses square brackets `[...]` to denote markup tags. Any square brackets in displayed text MUST be escaped.

### The Problem

Unescaped square brackets cause "Encountered malformed markup tag" errors:

```powershell
# ❌ WRONG - Will throw error at runtime
$prompt.AddChoice('[Back to main menu]')
# Error: "Encountered malformed markup tag at position 21."
```

Spectre.Console tries to parse `[Back` as a style tag (for colors, bold, etc.), which is invalid.

### The Solution: Double Your Brackets

Escape literal square brackets by doubling them:

```powershell
# ✅ CORRECT - Brackets are escaped
$prompt.AddChoice('[[Back to main menu]]')
# Displays: [Back to main menu]

# Other examples:
$label = 'Item [[0]]'                    # Displays: Item [0]
$example = 'Use [[1],[2],[3]] syntax'    # Displays: Use [1],[2],[3] syntax
$hint = 'Config [[debug]] not [[release]]' # Displays: Config [debug] not [release]
```

### When to Escape

**Always escape square brackets unless they are part of intentional markup tags:**

| Content | Escaped? | Example |
|---------|----------|---------|
| Choice text with brackets | YES | `'[[Back]]'` |
| Menu option with brackets | YES | `'Item [[1]]'` |
| Help text with array syntax | YES | `'Use [[0]] for array'` |
| Intentional markup (colors, styles) | NO | `'[red]Error[/]'` |
| User input that might contain brackets | YES | Use `Markup.Escape()` in C# methods |

### Important: Double Brackets Only for Display Escaping, NOT for String Comparisons

**Double brackets are ONLY for escaping brackets in text that will be DISPLAYED via Spectre.Console methods.**

Do NOT use double brackets in PowerShell string comparisons, string assignments outside of display contexts, or logic conditions:

```powershell
# ❌ WRONG - Double brackets in string comparison
if ($userInput -ieq '[[Reset to default]]') {
    # This will never match because $userInput contains single brackets
}

# ✅ CORRECT - Use single brackets for string comparisons
if ($userInput -ieq '[Reset to default]') {
    # This correctly matches user input with single brackets
}

# ❌ WRONG - Double brackets in variable assignment (non-display context)
$sentinel = '[[Reset to default]]'  # Only use double brackets when displaying

# ✅ CORRECT - Use single brackets internally, double only when displaying
$sentinel = '[Reset to default]'
$Console.MarkupLine("Hint: Enter $($sentinel)") # Would display: Hint: Enter [Reset to default]

# Or if you must display it in markup:
$Console.MarkupLine("Hint: Enter [[Reset to default]]")  # Would display: Hint: Enter [Reset to default]
```

**Rule of thumb:** Use double brackets only when passing text directly to Spectre.Console display methods (`.MarkupLine()`, `.AddChoice()`, etc.). Use single brackets everywhere else.

## Markup Tag Reference

Valid Spectre.Console markup tags include:

- **Colors:** `[red]`, `[green]`, `[blue]`, `[yellow]`, etc.
- **Decorations:** `[bold]`, `[dim]`, `[italic]`, `[underline]`, `[strikethrough]`
- **Background:** `[on red]`, `[on #FF0000]`
- **Combined:** `[bold red]`, `[bold on white]`
- **Close tag:** `[/]` closes the most recent tag

```powershell
$console.MarkupLine('[bold red]Error:[/] Something failed')     # ✅ Valid
$console.MarkupLine('[blue]INFO[/] Process complete')           # ✅ Valid
$prompt.Title = 'Configuration area:'                           # ✅ No tags needed
```

## Testing with TestConsole

### Setup

Import `Spectre.Console.Testing.dll` and use `TestConsole` for injected testing:

```powershell
BeforeAll {
    $testingDll = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\test\Spectre.Console.Testing.dll'
    Add-Type -Path $testingDll
}
```

### Accept IAnsiConsole Parameter

Always accept `IAnsiConsole` as a parameter to enable testability:

```powershell
function Show-ConfigMenuScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console  # Testability injection point
    )
    
    $prompt = [Spectre.Console.SelectionPrompt[string]]::new()
    $prompt.Title = 'Configuration area:'
    $prompt.AddChoice('Option 1') | Out-Null
    
    $selection = $prompt.Show($Console)  # Use injected console
}
```

### Test with TestConsole

In Pester tests, inject `TestConsole` instead of a real console:

```powershell
It 'Returns without throwing' {
    InModuleScope -ModuleName 'MyModule' {
        # Create test console with interactive capabilities
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Profile.Capabilities.Interactive = $true
        
        # Queue input: down arrow 4 times, then Enter
        $tc.Input.PushKey([ConsoleKey]::DownArrow)
        $tc.Input.PushKey([ConsoleKey]::DownArrow)
        $tc.Input.PushKey([ConsoleKey]::DownArrow)
        $tc.Input.PushKey([ConsoleKey]::DownArrow)
        $tc.Input.PushKey([ConsoleKey]::Enter)
        
        # Call function with test console
        { Show-ConfigMenuScreen -Console $tc } | Should -Not -Throw
        
        # Assert on output
        $tc.Output | Should -Match 'Configuration area'
    }
}
```

### Assertions on TestConsole Output

Access rendered output and input state:

```powershell
# Check output contains expected text
$tc.Output | Should -Match 'Option 1'
$tc.Output | Should -Match 'Option 2'

# Check all menu choices are present
$tc.Output | Should -Match 'Logging settings'
$tc.Output | Should -Match 'Back to main menu'
```

## SelectionPrompt Pattern

When building menu prompts:

```powershell
$prompt = [Spectre.Console.SelectionPrompt[string]]::new()
$prompt.Title = 'Choose an option:'           # No markup needed for title
$prompt.PageSize = 10                         # Optional: control visible items
$prompt.AddChoice('Option 1') | Out-Null
$prompt.AddChoice('Option 2') | Out-Null
$prompt.AddChoice('[[Back to menu]]') | Out-Null  # ⚠️ Escape the brackets!

$selection = $prompt.Show($Console)
```

## Common Pitfalls and Solutions

### Pitfall 1: Unescaped Brackets in Choice Text

```powershell
# ❌ WRONG
$prompt.AddChoice('[Back to menu]')  # Throws: "Encountered malformed markup tag"

# ✅ CORRECT
$prompt.AddChoice('[[Back to menu]]')
```

### Pitfall 2: Mixed Markup and Content

```powershell
# ❌ WRONG - User input not escaped
$userInput = "data[1]"
$console.MarkupLine($"[blue]User input:[/] {$userInput}")  # Error if not escaped

# ✅ CORRECT - Use MarkupLineInterpolated or escape manually in C# bridge
$console.MarkupLine("[blue]User input:[/] data[[1]]")  # Pre-escaped in PowerShell
```

### Pitfall 3: Invalid Style Names

```powershell
# ❌ WRONG
$console.MarkupLine('[rde]Error[/]')  # "rde" is not a valid color

# ✅ CORRECT
$console.MarkupLine('[red]Error[/]')
```

### Pitfall 4: Unclosed Tags

```powershell
# ❌ WRONG
$console.MarkupLine('[red]Error message')  # Missing [/] to close tag

# ✅ CORRECT
$console.MarkupLine('[red]Error message[/]')
```

## PowerShell-Specific Tips

### Use Out-Null for Method Return Values

Spectre.Console methods return objects that create noise in PowerShell output:

```powershell
# ❌ Outputs unwanted object information
$prompt.AddChoice('Option 1')
$prompt.AddChoice('Option 2')

# ✅ Suppress output
$prompt.AddChoice('Option 1') | Out-Null
$prompt.AddChoice('Option 2') | Out-Null
```

### Wrap IAnsiConsole Types Correctly

When accepting Spectre.Console types as parameters:

```powershell
param(
    [Parameter(Mandatory)]
    [Spectre.Console.IAnsiConsole]$Console  # ✅ Correct type annotation
)
```

### Avoid Static AnsiConsole Calls in Testable Code

```powershell
# ❌ NOT testable - uses static AnsiConsole
[Spectre.Console.AnsiConsole]::MarkupLine('[green]Done[/]')

# ✅ Testable - uses injected console parameter
$Console.MarkupLine('[green]Done[/]')
```

## Code Review Checklist for Spectre.Console

- [ ] All square brackets in choice text or displayed strings are escaped (doubled)?
- [ ] Markup tags are properly closed with `[/]`?
- [ ] Only valid color/style names are used?
- [ ] Functions accept `IAnsiConsole` parameter for testability?
- [ ] Tests use `TestConsole` injected via parameter?
- [ ] No hardcoded `AnsiConsole` static calls in production code?
- [ ] Method return values are suppressed with `| Out-Null`?
- [ ] All mock functions in tests match the parameter signature (especially `$Console`)?

## Examples

### Example 1: Configuration Menu with Escaped Back Option

```powershell
function Show-ConfigMenuScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Spectre.Console.IAnsiConsole]$Console
    )

    while ($true) {
        $prompt = [Spectre.Console.SelectionPrompt[string]]::new()
        $prompt.Title = 'Configuration area:'

        $prompt.AddChoice('Logging settings') | Out-Null
        $prompt.AddChoice('Mouse control') | Out-Null
        $prompt.AddChoice('[[Back to main menu]]') | Out-Null  # ✅ Escaped!

        $selection = $prompt.Show($Console)

        switch ($selection) {
            'Logging settings' {
                Show-LoggingScreen -Console $Console
            }
            'Mouse control' {
                Show-MouseScreen -Console $Console
            }
            default {
                return  # Back to main menu
            }
        }
    }
}
```

### Example 2: Test with Escaped Brackets

```powershell
It 'Handles back option correctly' {
    InModuleScope -ModuleName 'MyModule' {
        $tc = [Spectre.Console.Testing.TestConsole]::new()
        $tc.Profile.Capabilities.Interactive = $true
        
        # Select "Back to main menu"
        $tc.Input.PushKey([ConsoleKey]::DownArrow)
        $tc.Input.PushKey([ConsoleKey]::Enter)
        
        Show-ConfigMenuScreen -Console $tc
        
        # Output should show the unescaped text
        $tc.Output | Should -Match 'Back to main menu'  # Matches plain text
    }
}
```

## Related Instructions

- [powershell.instructions.md](./powershell.instructions.md) - PowerShell scripting best practices
- [powershell-pester-5.instructions.md](./powershell-pester-5.instructions.md) - Pester v5 testing conventions

---

**Remember:** When in doubt, escape your square brackets with `[[` and `]]`. This prevents 99% of Spectre.Console markup errors in PowerShell projects.

