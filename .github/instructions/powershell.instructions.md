---
applyTo: '**/*.ps1,**/*.psm1,**/*.psd1'
description: 'PowerShell cmdlet and scripting best practices based on Microsoft guidelines'
---  

# PowerShell Cmdlet Development Guidelines

This guide provides PowerShell-specific instructions to help GitHub Copilot generate idiomatic, safe, and maintainable scripts. It aligns with Microsoft’s PowerShell cmdlet development guidelines.

## Naming Conventions

- **Verb-Noun Format:**
  - Use approved PowerShell verbs (Get-Verb)
  - Use singular nouns
  - PascalCase for both verb and noun
  - Avoid special characters and spaces
- **Powershell Version**
  - Only use Powershell v5.7.1 or higher patterns and commands

```powershell
    $moduleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'LastWarAutoScreenshot.psd1'
    Import-Module $moduleManifest -Force
```

- **Parameter Names:**
  - Use PascalCase
  - Choose clear, descriptive names
  - Use singular form unless always multiple
  - Follow PowerShell standard names

- **Variable Names:**
  - Use PascalCase for public variables
  - Use camelCase for private variables
  - Avoid abbreviations
  - Use meaningful names
  - When naming variables it is crucial you avoid using any automatic variable names in the following list:
    - $? – Contains the execution status of the last command ($true if successful, $false if failed).
    - $^ – Contains the first token in the last line received by the session.
    - $_ – Same as $PSItem; contains the current object in a pipeline.
    - $args – Contains an array of values for undeclared parameters passed to a function, script, or script block.
    - $ConsoleFileName – Contains the path of the most recently used console file (.psc1).
    - $EnabledExperimentalFeatures – Contains a list of enabled experimental features.
    - $Error – Contains an array of the most recent error objects (most recent first).
    - $Event – Contains a PSEventArgs object representing the current event being processed.
    - $EventArgs – Contains the first event argument derived from EventArgs.
    - $EventSubscriber – Contains a PSEventSubscriber object representing the event subscriber.
    - $ExecutionContext – Contains an EngineIntrinsics object representing the execution context.
    - $false – Represents the Boolean value False.
    - $foreach – Contains the enumerator of a foreach loop (exists only during loop execution).
    - $HOME – Contains the full path to the user’s home directory.
    - $Host – Contains an object representing the current host application (e.g., console, ISE).
    - $input – Contains an enumerator that enumerates all input passed to a function or script.
    - $IsCoreCLR – Returns $true if PowerShell is running on .NET Core/PowerShell Core.
    - $IsLinux – Returns $true if the operating system is Linux.
    - $IsMacOS – Returns $true if the operating system is macOS.
    - $IsWindows – Returns $true if the operating system is Windows.
    - $LASTEXITCODE – Contains the exit code of the last native command (executable).
    - $Matches – Contains the results of the last regular expression match.
    - $MyInvocation – Contains information about the current command invocation.
    - $NestedPromptLevel – Contains the current level of nested prompts.
    - $null – Represents a null value.
    - $PID – Contains the process ID of the current PowerShell process.
    - $PROFILE – Contains the path to the current user’s PowerShell profile script.
    - $PSBoundParameters – Contains a dictionary of parameters bound to the current function or script.
    - $PSCmdlet – Contains the current PSCmdlet object used in a cmdlet.
    - $PSCommandPath – Contains the full path of the current script or command.
    - $PSCulture – Contains the culture used by the current session.
    - $PSDebugContext – Contains debugging context information.
    - $PSEdition – Contains the edition of PowerShell (e.g., Core, Desktop).
    - $PSHOME – Contains the path to the PowerShell installation directory.
    - $PSItem – Same as $_; the current pipeline object.
    - $PSScriptRoot – Contains the directory path of the current script.
    - $PSSenderInfo – Contains information about the sender of a remote command.
    - $PSUICulture – Contains the UI culture used by the current session.
    - $PSVersionTable – Contains a hashtable with detailed version information about PowerShell.
    - $PWD – Contains the current working directory.
    - $Sender – Contains the sender of an event.
    - $ShellId – Contains the unique identifier of the current shell.
    - $StackTrace – Contains the call stack of the most recent error.
    - $switch – Contains the current switch statement value during processing.
    - $this – Refers to the current object in a foreach or switch loop.
    - $true – Represents the Boolean value True.
    - $ShellId – Contains the unique identifier of the current shell.
    - $StackTrace – Contains the call stack of the most recent error.
    - $switch – Contains the current switch statement value during processing.
    - $this – Refers to the current object in a foreach or switch loop.
    - $true – Represents the Boolean value True.

- **Common Mistakes to Avoid**
  - Never introduce whitespace before the terminating `'@` of a here-string block
  - `[cmdletbinding()]` directly followed by function parameters should always be the first lines in a function block

### Example 1

```powershell
function Get-UserProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter()]
        [ValidateSet('Basic', 'Detailed')]
        [string]$ProfileType = 'Basic'
    )

    process {
        # Logic here
    }
}
```

## Parameter Design

- **Standard Parameters:**
  - Use common parameter names (`Path`, `Name`, `Force`)
  - Follow built-in cmdlet conventions
  - Do not use aliases
  - Document parameter purpose

- **Parameter Names:**
  - Use singular form unless always multiple
  - Choose clear, descriptive names
  - Follow PowerShell conventions
  - Use PascalCase formatting

- **Type Selection:**
  - Use common .NET types
  - Implement proper validation
  - Consider ValidateSet for limited options
  - Enable tab completion where possible

- **Switch Parameters:**
  - Use [switch] for boolean flags
  - Avoid $true/$false parameters
  - Default to $false when omitted
  - Use clear action names

### Example 2

```powershell
function Set-ResourceConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [ValidateSet('Dev', 'Test', 'Prod')]
        [string]$Environment = 'Dev',
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Tags
    )
    
    process {
        # Logic here
    }
}
```

## Pipeline and Output

- **Pipeline Input:**
  - Use `ValueFromPipeline` for direct object input
  - Use `ValueFromPipelineByPropertyName` for property mapping
  - Implement Begin/Process/End blocks for pipeline handling
  - Document pipeline input requirements

- **Output Objects:**
  - Return rich objects, not formatted text
  - Use PSCustomObject for structured data
  - Avoid Write-Host for data output
  - Enable downstream cmdlet processing

- **Pipeline Streaming:**
  - Output one object at a time
  - Use process block for streaming
  - Avoid collecting large arrays
  - Enable immediate processing

- **PassThru Pattern:**
  - Default to no output for action cmdlets
  - Implement `-PassThru` switch for object return
  - Return modified/created object with `-PassThru`
  - Use verbose/warning for status updates

### Example 3

```powershell
function Update-ResourceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('Active', 'Inactive', 'Maintenance')]
        [string]$Status,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Write-Verbose "Starting resource status update process"
        $timestamp = Get-Date
    }

    process {
        # Process each resource individually
        Write-Verbose "Processing resource: $Name"
        
        $resource = [PSCustomObject]@{
            Name = $Name
            Status = $Status
            LastUpdated = $timestamp
            UpdatedBy = $env:USERNAME
        }

        # Only output if PassThru is specified
        if ($PassThru) {
            Write-Output $resource
        }
    }

    end {
        Write-Verbose "Resource status update process completed"
    }
}
 ```

## Error Handling and Safety

- **ShouldProcess Implementation:**
  - Use `[CmdletBinding(SupportsShouldProcess = $true)]`
  - Set appropriate `ConfirmImpact` level
  - Call `$PSCmdlet.ShouldProcess()` for system changes
  - Use `ShouldContinue()` for additional confirmations

- **Message Streams:**
  - `Write-Verbose` for operational details with `-Verbose`
  - `Write-Warning` for warning conditions
  - `Write-Error` for non-terminating errors
  - `throw` for terminating errors
  - Avoid `Write-Host` except for user interface text

- **Error Handling Pattern:**
  - Use try/catch blocks for error management
  - Set appropriate ErrorAction preferences
  - Return meaningful error messages
  - Use ErrorVariable when needed
  - Include proper terminating vs non-terminating error handling

- **Non-Interactive Design:**
  - Accept input via parameters
  - Avoid `Read-Host` in scripts
  - Support automation scenarios
  - Document all required inputs

### Example 4

```powershell
function Remove-UserAccount {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Starting user account removal process"
        $ErrorActionPreference = 'Stop'
    }

    process {
        try {
            # Validation
            if (-not (Test-UserExists -Username $Username)) {
                Write-Error "User account '$Username' not found"
                return
            }

            # Confirmation
            $shouldProcessMessage = "Remove user account '$Username'"
            if ($Force -or $PSCmdlet.ShouldProcess($Username, $shouldProcessMessage)) {
                Write-Verbose "Removing user account: $Username"
                
                # Main operation
                Remove-ADUser -Identity $Username -ErrorAction Stop
                Write-Warning "User account '$Username' has been removed"
            }
        }
        catch [Microsoft.ActiveDirectory.Management.ADException] {
            Write-Error "Active Directory error: $_"
            throw
        }
        catch {
            Write-Error "Unexpected error removing user account: $_"
            throw
        }
    }

    end {
        Write-Verbose "User account removal process completed"
    }
}
```

## Documentation and Style

- **Comment-Based Help:** Include comment-based help for any function or cmdlet. Inside the function, add a `<# ... #>` help comment with at least:
  - `.SYNOPSIS` Brief description
  - `.DESCRIPTION` Detailed explanation
  - `.EXAMPLE` sections with practical usage
  - `.PARAMETER` descriptions
  - `.OUTPUTS` Type of output returned
  - `.NOTES` Additional information

- Always modify comment-based help blocks to reflect any code changes made to the relevant function
- Excluding comment-based help blocks which are mandatory for every function, keep inline comments to a minimum
- If you believe inline comments outside of comment-based help are too abundant, explain and ask if you should remove or condense some

- **Consistent Formatting:**
  - Follow consistent PowerShell style
  - Use proper indentation (4 spaces recommended)
  - Opening braces on same line as statement
  - Closing braces on new line
  - Use line breaks after pipeline operators
  - PascalCase for function and parameter names
  - Avoid unnecessary whitespace

- **Pipeline Support:**
  - Implement Begin/Process/End blocks for pipeline functions
  - Use ValueFromPipeline where appropriate
  - Support pipeline input by property name
  - Return proper objects, not formatted text

- **Avoid Aliases:** Use full cmdlet names and parameters
  - Avoid using aliases in scripts (e.g., use Get-ChildItem instead of gci); aliases are acceptable for interactive shell use.
  - Use `Where-Object` instead of `?` or `where`
  - Use `ForEach-Object` instead of `%`
  - Use `Get-ChildItem` instead of `ls` or `dir`

## Full Example: End-to-End Cmdlet Pattern

```powershell
function New-Resource {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Development', 'Production')]
        [string]$Environment = 'Development'
    )
    
    begin {
        Write-Verbose "Starting resource creation process"
    }
    
    process {
        try {
            if ($PSCmdlet.ShouldProcess($Name, "Create new resource")) {
                # Resource creation logic here
                Write-Output ([PSCustomObject]@{
                    Name = $Name
                    Environment = $Environment
                    Created = Get-Date
                })
            }
        }
        catch {
            Write-Error "Failed to create resource: $_"
        }
    }
    
    end {
        Write-Verbose "Completed resource creation process"
    }
}
```

## Example Folder Structure

- Don't copy names below, just use the structure and names that make sense for the project

MyModule/
├── MyModule.psd1          # Module manifest
├── MyModule.psm1          # Main module file (entry point)
├── public/                # Contains functions intended for export
│   ├── Get-Thing.ps1
│   └── Set-Thing.ps1
├── private/               # Contains internal helper functions
│   ├── Test-Thing.ps1
│   └── Invoke-Thing.ps1
├── tests/                 # Unit tests using Pester
│   └── MyModule.Tests.ps1
├── examples/              # Usage examples for documentation
│   └── Example1.ps1
└── docs/         # Additional docs (other than README.md)
