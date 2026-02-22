BeforeAll {
    # Tests\ConsoleApp\ is two levels below the module root; go up twice to find the manifest
    $moduleManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'ConsoleAppBridge' {

    Context 'Type loading' {
        It 'Type [LastWarAutoScreenshot.ConsoleAppBridge] should be accessible after module import' {
            { [LastWarAutoScreenshot.ConsoleAppBridge] } | Should -Not -Throw
        }

        It '[LastWarAutoScreenshot.ConsoleAppBridge] should be a static class' {
            $type = [LastWarAutoScreenshot.ConsoleAppBridge]
            $type | Should -Not -BeNullOrEmpty
            $type.IsAbstract | Should -BeTrue
            $type.IsSealed | Should -BeTrue
        }

        It '[Spectre.Console.AnsiConsole] type should be accessible after module import' {
            { [Spectre.Console.AnsiConsole] } | Should -Not -Throw
        }

        It '[Spectre.Console.IAnsiConsole] interface should be accessible after module import' {
            { [Spectre.Console.IAnsiConsole] } | Should -Not -Throw
        }
    }

    Context 'CreateConsole' {
        It 'Should return a non-null object' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return an object that implements IAnsiConsole' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()
            $result | Should -BeOfType [Spectre.Console.IAnsiConsole]
        }
    }

    Context 'CreateSelectionPrompt' {
        It 'Should return a non-null SelectionPrompt<string> object' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt('Choose one', @('Option A', 'Option B'))
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should set the Title property to the supplied title' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt('My Title', @('One', 'Two'))
            $result.Title | Should -Be 'My Title'
        }

        It 'Should not throw when title is null (PowerShell coerces $null to empty string for string params)' {
            # PowerShell coerces $null to '' for .NET string parameters; the guard in C# only fires for
            # direct C# callers.  Verify the coercion is transparent and the call succeeds.
            { [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt($null, @('A')) } | Should -Not -Throw
        }

        It 'Should throw ArgumentNullException when choices is null' {
            { [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt('Title', $null) } | Should -Throw
        }

        It 'Should accept an empty choices array without throwing' {
            { [LastWarAutoScreenshot.ConsoleAppBridge]::CreateSelectionPrompt('Empty', @()) } | Should -Not -Throw
        }
    }

    Context 'CreateTable' {
        It 'Should return a non-null Table object' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('Col1', 'Col2'))
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return an object of type Spectre.Console.Table' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('Name', 'Value'))
            $result | Should -BeOfType [Spectre.Console.Table]
        }

        It 'Should use Rounded border style' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@('A'))
            # Rounded border is the project-standard style — verify it matches the static property
            $result.Border | Should -Be ([Spectre.Console.TableBorder]::Rounded)
        }

        It 'Should throw ArgumentNullException when columns is null' {
            { [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable($null) } | Should -Throw
        }

        It 'Should accept an empty columns array without throwing' {
            { [LastWarAutoScreenshot.ConsoleAppBridge]::CreateTable(@()) } | Should -Not -Throw
        }
    }

    Context 'CreatePanel' {
        It 'Should return a non-null Panel object' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel('Body text', 'Header')
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return an object of type Spectre.Console.Panel' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel('Content', 'Title')
            $result | Should -BeOfType [Spectre.Console.Panel]
        }

        It 'Should set the Header property when a non-empty header is provided' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel('Body', 'My Header')
            $result.Header | Should -Not -BeNullOrEmpty
            $result.Header.Text | Should -Be 'My Header'
        }

        It 'Should leave Header null when an empty string header is provided' {
            $result = [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel('Body', '')
            $result.Header | Should -BeNullOrEmpty
        }

        It 'Should not throw when content is null (PowerShell coerces $null to empty string for string params)' {
            # Same coercion caveat as CreateSelectionPrompt — $null becomes ''
            { [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel($null, 'Header') } | Should -Not -Throw
        }

        It 'Should not throw when header is null (PowerShell coerces $null to empty string for string params)' {
            { [LastWarAutoScreenshot.ConsoleAppBridge]::CreatePanel('Content', $null) } | Should -Not -Throw
        }
    }
}
