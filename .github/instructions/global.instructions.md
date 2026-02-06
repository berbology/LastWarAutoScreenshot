# Global Copilot Instructions for General Projects

## IMPORTANT - How You Interact With Me

1. Never sugarcoat the truth when responding.
2. ALWAYS be brutally honest, even if it hurts.
3. Never omit anything, be candid
4. If you are unsure about something, say so.
5. If you don't know the answer, say so.
6. If you think I am wrong, say so.
7. If you think I am being unreasonable, say so.
8. If you think I am being silly, say so.
9. If you think I am being arrogant, say so.
10. If you think I am being ignorant, say so.
11. If you think I am being biased, say so.
12. If you think I am being unfair, say so.
13. If you think I misunderstand something, say so.
14. Always give detailed explanations and reasoning for your answers when asked to, otherwise be concise.
15. When you're asked for detailed explanations I ALWAYS need to understand BOTH the "what" AND the "why"
16. If you provide code, explain why you wrote it that way, what alternatives you considered, and why you rejected them.
17. If you provide a solution, explain why it works, assumptions, limitations.
18. If you recommend, explain why it's the best option
19. If you recommend, explain all trade-offs involved, risks it carried
20. Always consider the ai agent context of the project and my specific requirements when providing answers.
21. If you ever feel you have 2 conflicting instructions, ask me which one you should follow. Never assume.

## IMPORTANT - How You Suggest Code Changes

1. When suggesting code changes:
    1. Always ensure alignment with the existing project architecture and design patterns
    2. Do not introduce new libraries or frameworks unless absolutely necessary.
    3. Always prioritize simplicity, readability, and maintainability in your code suggestions.
    4. Avoid complex or convoluted solutions that may be difficult to understand or maintain in the future.
    5. Only ever refactor code when I explicitly ask you to do so.
    6. You've often tended to refactor code unnecessarily, introducing bugs and making the code harder to understand.
    7. Always follow all coding standards & conventions that I have established for the project.
        1. Include naming conventions, brace styles, indentation, and commenting practices.
        2. Consistency is key to maintaining a clean and professional codebase.
    8. Always include concise, minimal debug output to help with troubleshooting and monitoring the system.
        1. Always provide meaningful messages that can help identify issues or confirm correct operation.
    9. Always consider the project testing strategy
        1. The project includes unit tests using the Pester framework, so ensure that any new code can be easily tested.
        2. Provide mock implementations for hardware interfaces as needed to facilitate testing.
   10. Always follow my specific coding standards, architecture, and design patterns.
   11. Always meet project hardware constraints and performance requirements.
   12. Always keep these factors in mind when answering my questions or providing code.
   13. Avoid introducing new dependencies unless absolutely necessary.
   14. Ensure that any new dependencies are compatible with the existing ones.
   15. Always consider the overall user experience of the system.
        1. The goal is to create a reliable, responsive, accurate and automatable Powershell module to:
           1. Move the mouse to an x,y location, initially given by the user
           2. Click the mouse to open a window
           3. Take a screen shot
           4. Scroll to the next page of records
           5. Take a screen shot
           6. Repeat until no more rows exist
        2. The system should provide logging of various levels: Info, Warning, Error, Verbose to be customisable by the end user
        3. Once screenshots have been taken, a user-configurable setting allows them to optionally be uploaded to azure blob storage for processing
        4. All mouse movements and clicks should appear human to avoid bot detection algorithms
           1. Do not take a straight path to the destination location
           2. Vary duration of and time between mouse-up and mouse-down events

## IMPORTANT - How You Write Tests

1. When writing tests, always:
   1. Ensure that they cover all key functionalities of the system.
   2. Use mock objects to simulate network responses as needed.
   3. Ensure they are easy to run and understand
   4. Use clear, descriptive names for test cases, and provide comments to explain the purpose of each test.
   5. Ensure that tests can be run independently and do not rely on external state or configuration.
   6. Ensure that they provide meaningful feedback.
   7. Use assertions to verify expected outcomes
   8. Provide detailed error messages to help identify issues when tests fail.
   9. Strive for high test coverage to ensure that the system is robust and reliable.
   10. consider the performance of the tests.
   11. Avoid long-running tests or tests that require complex setup or teardown procedures.
   12. Strive for fast and efficient tests that can be run frequently during development.
   13. Consider maintainability of the tests.
   14. Use consistent coding styles and conventions, and organize tests in a logical manner.
   15. Ensure that tests are easy to update and modify as the system evolves.
   16. Consider the integration of tests into the overall development workflow.
   17. Use CI tools to auto-run tests on code changes, and ensure tests are part of the code review process.
   18. Consider test documentation.
       1. Provide clear and concise documentation for the test suite
       2. Include instructions for running tests, interpreting results, and adding new tests.
   19. Ensure tests are properly isolated.
       1. Each test should be independent and not rely on the state or behaviour of other tests.
       2. Use setup and tear-down methods to create a clean testing environment for each test case.
   20. Consider edge cases and error conditions.
       1. Ensure that tests cover not only the expected system behaviour but also how it handles unexpected inputs or failures.
   21. Consider the use of test doubles (mocks, stubs, fakes) to simulate complex or external dependencies.
       1. This can help isolate the code under test and make tests more reliable and faster.
   22. Consider the overall test strategy and how individual tests fit into it.
       1. Consider the balance between unit, integration and end-to-end tests, and how to prioritize testing efforts.
   23. Ensure Tests are kept as simple as possible.
       1. Avoid complex logic or dependencies in test code, and strive for clarity and simplicity.
   24. Consider the use of parameterized tests to cover multiple input scenarios with a single test case.
       1. This can help reduce code duplication and improve test coverage.
   25. Consider the use of code coverage tools to measure the effectiveness of the test suite.
       1. Aim for high coverage of critical code paths, recognizing that 100% coverage is not always necessary or practical.
   26. Avoid brittle unit tests.
       1. Tests should be resilient to codebase changes and not break due to minor refactoring or implementation details.
2. It is crucial that every time you write a new function or method, you also write corresponding unit tests for it
    1. Covering error cases, edge cases, parameter sanitization, and other relevant scenarios.
    2. This ensures all new code is properly tested, helping maintain overall quality and reliability of the codebase.

## IMPORTANT - OTHER RULES

1. NEVER delete comments or commented-out code without asking first and showing me what you plan to delete.
   1. They're crucial in understanding the code and its purpose, and must be preserved unless clearly obsolete or wrong.
   2. Some commented out code is there for a reason, such as for future reference or debugging purposes.
   3. Always err on the side of caution, preserving comments and commented out code unless explicitly told otherwise.
2. Always ask clarifying questions if you are unsure about something.
   1. If I provide incomplete or ambiguous information, ask me for more details before proceeding.
   2. If you don't understand my requirements or constraints, ask me to clarify them.
   3. If you are unsure about the best approach or solution, ask me for my input or preferences.
   4. Always seek to understand my needs and goals before providing answers or code.

## Common Issues & Solutions

## When suggesting code changes

1. Maintain existing architecture and abstraction layers
2. Include proper error handling and validation
3. Consider power consumption and memory usage
4. Add appropriate debug output for troubleshooting
5. Use non-blocking calls and avoid long delays
