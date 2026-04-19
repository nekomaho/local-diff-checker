# Local Diff Checker

> [!IMPORTANT]
> **Security Warning**: This tool is designed for **local development use only**. It is not intended to be deployed on a public server or any shared environment. The application executes local Git commands and accesses your file system based on user input, which could pose a significant security risk if exposed to the internet.

This is a local tool featuring a GitHub-style split diff view and Markdown-based comment saving capabilities.

## Setup

In this project, dependencies are installed locally within the project (`vendor/bundle`).

```bash
# Install dependencies
bundle config set --local path 'vendor/bundle'
bundle install

# Prepare configuration
cp config.sample.yml config.yml
```

## Starting the Application

Launch the Sinatra application.

```bash
# Start the application
bundle exec ruby app.rb
```

By default, the application is accessible at `http://localhost:4567`. Open it in your browser and enter the full path to your Git repository.

## Running Tests

Run tests using RSpec.

```bash
# Run all tests
bundle exec rspec

# Run a specific test
bundle exec rspec spec/lib/git_manager_spec.rb
```

## Configuration

You can configure the storage location and frequently used repository paths in `config.yml`.

```yaml
# Directory for storing Markdown diff files and comments
storage_dir: './data'

# Default port for the application
port: 4567

# List of Git repository paths to show on the index page
# repo_paths:
#   - /path/to/repo1
#   - /path/to/repo2
```

If `repo_paths` is configured, you can select the target repository from a list on the home page. You can also still enter a manual path.

## Key Features

- **Repository List**: Frequently used repository paths can be listed in the configuration file for quick selection.
- **Git Diff View**: Automatically detects differences between the base branch (e.g., main/master) and the current branch, displaying them in a split view.
- **Commenting Feature**: Allows posting comments on each line of the diff.
- **Markdown Saving**: Both the Git diff snapshot and your comments are bundled and saved together. Files are named `[repo-name]-[branch-name]-[commit-hash]-[sequence-number].md` for committed changes, or `[repo-name]-[branch-name]-[commit-hash]-[sequence-number]_uncommited.md` for unstaged changes. (Note: Slashes in branch names are replaced with double hyphens `--` to ensure safe file paths.)
- **Automatic Version Control**: When branch differences are updated, a new sequential Markdown file is automatically generated.

## License

This project is licensed under the BSD License.
