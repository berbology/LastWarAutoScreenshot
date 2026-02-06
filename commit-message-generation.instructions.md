# Commit Message Generation Instructions

These instructions define how commit messages should be generated for this project.

## Guidelines

1. **Concise and Descriptive**:
   1. Be extremely detailed with file changes and reasons for changes
   2. Use lots of emojis.
   3. Use conventional commit format: type(scope): description
   4. Include relevant issue numbers using 'Fixes #123' or 'Closes #456' format
2. **Imperative Mood**: Use the imperative mood (e.g., "Add feature" instead of "Added feature").
3. **Structure**:
   - **Header**: A single line summarizing the change (max 50 characters).
     - Use types: feat, fix, docs, style, refactor, perf, test, chore, ci, move
     - Include scope when relevant (e.g., api, ui, auth)
   - **Body** (optional): A detailed explanation of the change, if necessary.
     - List key changes as bullet points for easy scanning
   - **Footer** (optional): Any references to issues, pull requests, or breaking changes.
4. **Examples**:
   - `Fix bug in screenshot similarity detection`
   - `Add support for YAML configuration files`
   - `Refactor mouse movement logic for better performance`

## Automation

Commit messages may be auto-generated based on the changes made, but they must adhere to the above guidelines. Review and edit auto-generated messages as needed to ensure clarity and accuracy.
