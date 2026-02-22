using System;
using Spectre.Console;

namespace LastWarAutoScreenshot
{
    /// <summary>
    /// Bridge class that exposes PowerShell-friendly static factory methods over
    /// Spectre.Console's fluent and generic API.  Keeping this layer thin means
    /// PowerShell screen functions remain readable and do not need to deal with
    /// C# generics or fluent builder chains directly.
    /// </summary>
    /// <remarks>
    /// This class contains no P/Invoke calls.  SetLastError is not applicable.
    /// All methods are pure managed .NET code referencing Spectre.Console.dll.
    ///
    /// Testability: every screen function should accept an
    /// <see cref="IAnsiConsole"/> parameter.  In production, pass the result of
    /// <see cref="CreateConsole"/>.  In Pester tests, pass a
    /// <c>Spectre.Console.Testing.TestConsole</c> instance and assert on its
    /// <c>Output</c> property.
    /// </remarks>
    public static class ConsoleAppBridge
    {
        /// <summary>
        /// Returns the default live ANSI console (the real terminal).
        /// </summary>
        /// <returns>
        /// The singleton <see cref="IAnsiConsole"/> instance used by
        /// <see cref="AnsiConsole"/> for all interactive output.
        /// </returns>
        public static IAnsiConsole CreateConsole()
        {
            return AnsiConsole.Console;
        }

        /// <summary>
        /// Creates a <see cref="SelectionPrompt{T}"/> pre-populated with the
        /// supplied string choices.  Call <c>.Show(console)</c> on the returned
        /// object to display the interactive prompt and capture the user's
        /// selection.
        /// </summary>
        /// <param name="title">
        /// The markup string displayed as the prompt title above the choice list.
        /// </param>
        /// <param name="choices">
        /// The selectable string choices to add to the prompt.
        /// </param>
        /// <returns>
        /// A configured <see cref="SelectionPrompt{String}"/> ready to be shown.
        /// </returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="title"/> or <paramref name="choices"/> is
        /// <c>null</c>.
        /// </exception>
        public static SelectionPrompt<string> CreateSelectionPrompt(string title, string[] choices)
        {
            if (title == null) throw new ArgumentNullException(nameof(title));
            if (choices == null) throw new ArgumentNullException(nameof(choices));

            var prompt = new SelectionPrompt<string> { Title = title };
            foreach (var choice in choices)
            {
                prompt.AddChoice(choice);
            }
            return prompt;
        }

        /// <summary>
        /// Creates a <see cref="Table"/> with a Rounded border and the specified
        /// column headers.  Add rows by calling
        /// <c>table.AddRow(string[])</c> after creation.
        /// </summary>
        /// <param name="columns">The column header display names.</param>
        /// <returns>A configured <see cref="Table"/> with Rounded border style.</returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="columns"/> is <c>null</c>.
        /// </exception>
        public static Table CreateTable(string[] columns)
        {
            if (columns == null) throw new ArgumentNullException(nameof(columns));

            var table = new Table();
            table.Border = TableBorder.Rounded;
            foreach (var col in columns)
            {
                table.AddColumn(new TableColumn(col));
            }
            return table;
        }

        /// <summary>
        /// Creates a <see cref="Panel"/> containing the supplied markup content
        /// and an optional header title.
        /// </summary>
        /// <param name="content">
        /// The Spectre.Console markup string rendered inside the panel body.
        /// </param>
        /// <param name="header">
        /// The panel header title.  Pass an empty string to render a panel with
        /// no header.
        /// </param>
        /// <returns>A configured <see cref="Panel"/>.</returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="content"/> or <paramref name="header"/> is
        /// <c>null</c>.
        /// </exception>
        public static Panel CreatePanel(string content, string header)
        {
            if (content == null) throw new ArgumentNullException(nameof(content));
            if (header == null) throw new ArgumentNullException(nameof(header));

            var panel = new Panel(content);
            if (!string.IsNullOrEmpty(header))
            {
                panel.Header = new PanelHeader(header);
            }
            return panel;
        }
    }
}
