# Pull Request Description Generation Instructions

These instructions define how pull request descriptions should be generated for this project.

## Guidelines

1. **Clear and Informative**: Descriptions should clearly explain the purpose and scope of the pull request.
   1. Use lots of emojis.
   2. Use conventional pull request format: type(scope): description
   3. Use imperative mood: 'Add feature' not 'Added feature'
   4. Use types: feat, fix, docs, style, refactor, perf, test, chore, ci, move
   5. Include scope when relevant (e.g., api, ui, auth)
2. **Structure**:
   - **Title**: A concise summary of the pull request (max 50 characters).
   - **Description**: A detailed explanation of the changes, including:
     - What was changed
     - Why the change was necessary
     - How the change was implemented
     - List key changes as bullet points for easy scanning
     - Include relevant issue numbers using 'Fixes #123' or 'Closes #456' format
   - **Testing**: A summary of how the changes were tested.
   - **References**: Links to related issues, pull requests, or documentation.
3. **Examples**:
   - Title: `feat(config): Add support for YAML configuration files 📝`
   - Description:

     ```
     This pull request adds support for YAML configuration files in addition to JSON. YAML support was added to improve readability and flexibility for users. 🎉

     Changes:
     - 🛠️ Updated config loader to parse both JSON and YAML files.
     - 📄 Updated README.md path to point to its new location in src/LastWarAutoScreenshot/Docs.

     Testing:
     - ✅ Unit tests were added for YAML parsing.
     - 🧪 Manual testing was performed with sample YAML files.

     References:
     - Resolves #123 🔗
     ```

## Automation

Pull request descriptions may be auto-generated based on the changes made, but they must adhere to the above guidelines. Review and edit auto-generated descriptions as needed to ensure clarity and accuracy.
