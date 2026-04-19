# Project Rules and Guidelines

To maintain the quality and consistency of this project, please adhere to the following rules:

1.  **Language Policy**: Use English for all aspects of the project, including source code, comments, documentation, and commit messages.
2.  **Test Coverage**: When making changes to the code, ensure that you write corresponding tests whenever possible.
3.  **Validation**: After modifying the code, always execute the existing tests to verify that your changes have not introduced any regressions. (Note: Testing is not required for changes to non-programmatic files, such as Markdown or configuration files.)
4.  **Commit Workflow**: Only commit your changes after you have verified that all tests pass successfully.
5.  **Task Classification**: At the start of any task, ask the user whether the request is a "Modification", "Bug Fix", or "Investigation".
6.  **Workflow by Task Type**:
    - For **Modification** or **Bug Fix**:
        1. Ask the user for permission to switch to the `main` branch and perform a `git pull`.
        2. Create a new branch for the changes.
    - For **Bug Fix**: Always add a reproduction test case to verify the bug before implementing the fix.
    - For **Investigation**: Work directly on the current branch; do not create a new branch.
7.  **RSpec Organization**: 
    - Maintain a 1:1 relationship between a target `.rb` file and its corresponding `_spec.rb` file.
    - If multiple spec files are needed for a single `.rb` file, ask for user confirmation.
    - If confirmed, create a directory with the same name as the target file within the `spec` folder and place the spec files inside it.
