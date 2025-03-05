# Git Commit AI Assistant

This repository contains two Bash scripts—**`metasmartpush.sh`** and **`smartpush.sh`**—that integrate with an AI-powered commit message generator. Both scripts automatically generate concise Git commit messages by analyzing the staged changes and recent commit history, then using the Ollama API to suggest messages. They are intended to help maintain a clear, consistent commit history and speed up your development workflow.

---

## Overview

These scripts automate the process of generating a Git commit message using an AI model. They leverage the Ollama API to fetch suggestions based on the Git diff and recent commit context. The generated messages follow best practices by being concise (under 72 characters) and using the imperative mood. While both scripts perform similar functions, each has a slightly different approach and configuration:

- **`metasmartpush.sh`**:
  - Queries the Ollama API to retrieve available AI models dynamically.
  - Iterates over multiple models, benchmarks response times, and displays a summary for user selection.
  - Designed for environments where multiple AI models are available for comparison.

- **`smartpush.sh`**:
  - Uses a fixed default model (e.g., `mistral:7b`) and a preconfigured default tag (e.g., `feat:`) for commit messages.
  - Provides a simpler workflow with added debugging logs.
  - Retries message generation if the API response is invalid and allows manual input if needed.

---

## Features

- **Automatic Git staging and diff generation**: Both scripts automatically stage changes (`git add .`) and retrieve the diff for commit message context.
- **Dynamic AI model selection** (`metasmartpush.sh`): Automatically lists and benchmarks multiple available models.
- **Fixed model with default tag** (`smartpush.sh`): Uses a preconfigured model and prepends a default tag to the generated message.
- **User interaction**: Prompts the user to select or edit the generated commit message before committing.
- **Debug support**: Saves logs (e.g., Git diff excerpts and API responses) to temporary files for debugging purposes.

---

## Prerequisites

Before using these scripts, ensure you have the following installed:

- **Git**: The scripts must be run inside a Git repository.
- **`curl`**: For interacting with the Ollama API.
- **`jq`**: A command-line JSON processor used to build and parse JSON requests and responses.
- **Ollama Server**: An instance of the Ollama API server running and accessible.
  - The host is set to `http://localhost:11434` by default.
- **Bash**: The scripts are written for Bash (tested with Bash 4+).

---

## Installation and Setup

1. **Clone the repository** (or copy the scripts into your Git project):

    ```bash
    git clone https://github.com/luisriverag/ollama_gitai/
    cd your-repo-directory
    ```

2. **Ensure that the scripts have execute permissions**:

    ```bash
    chmod +x metasmartpush.sh smartpush.sh
    ```

3. **Install Dependencies**:

    - For `jq`:

      ```bash
      sudo apt-get install jq   # Debian/Ubuntu
      ```

    - For `curl`: Typically preinstalled, but install via your package manager if needed.

4. **Verify Ollama Server is running**:

    - Start the Ollama server on the specified host and port.
    - If necessary, adjust the host URLs in the scripts to match your setup.

---

## Configuration

Both scripts can be customized by modifying variables at the top of the file:

- **`metasmartpush.sh`**:
  - `OLLAMA_HOST`: URL of the Ollama API server.
  - Additional environment setups or host-specific configurations can be adjusted as needed.

- **`smartpush.sh`**:
  - `OLLAMA_MODEL`: The default AI model to use (e.g., `mistral:7b`).
  - `OLLAMA_HOST`: The host URL of your Ollama API server.
  - `DEFAULT_TAG`: A default prefix (such as `feat:`) appended to commit messages.

Make sure that these variables reflect your actual environment before running the scripts.

---

## Usage

### `metasmartpush.sh`

1. **Stage Your Changes**: The script automatically stages all changes (`git add .`). Ensure that you have uncommitted changes before running.

2. **Run the Script**:

    ```bash
    ./metasmartpush.sh
    ```

3. **Follow the Prompts**:
    - The script will:
      - Fetch available AI models from the Ollama server.
      - Retrieve and display multiple commit message suggestions along with response times.
      - Prompt you to choose a commit message by entering its corresponding number.
      - Allow you to accept, abort, or edit the chosen commit message.

4. **Commit and Push**: Upon confirmation, the script commits the changes and pushes them to your repository.

---

### `smartpush.sh`

1. **Ensure Changes are Present**: Like the other script, this one stages changes and requires a Git diff to be present.

2. **Run the Script**:

    ```bash
    ./smartpush.sh
    ```

3. **Review the AI-Generated Message**:
    - The script creates a prompt using the Git branch, recent commits, and the diff.
    - It calls the Ollama API to generate a commit message. If the response is empty or invalid, it retries or allows for manual input.
    - The default tag (e.g., `feat:`) is prepended to the commit message.

4. **User Interaction**: You will be asked to confirm, edit, or abort the commit message.

5. **Commit and Push**: After confirmation, the script commits your changes and pushes them to the remote repository.

---

## Script Details

### AI Integration and Prompt Generation

- **Prompt Construction**:
  - Both scripts construct a detailed prompt that includes:
    - The current Git branch.
    - Recent commit messages.
    - A list of changed files.
    - An excerpt from the current Git diff.
  - This prompt is designed to guide the AI in generating a concise, imperative, and meaningful commit message.

- **API Call**:
  - The prompt is encoded into a JSON request using `jq`.
  - A POST request is sent to the Ollama API endpoint `/api/generate` with the JSON payload.
  - The scripts parse the response to extract the commit message.

---

### Git Integration

- The scripts check if they are run inside a Git repository.
- They automatically stage changes (`git add .`) and use Git commands to fetch:
  - The current branch name.
  - Recent commit history.
  - A diff excerpt of the staged changes.
- Finally, after generating and confirming the commit message, they execute `git commit` and `git push`.

---

## Troubleshooting

- **No Git Repository Detected**:
  - Ensure that you are running the scripts inside a valid Git repository.

- **Missing Dependencies**:
  - Install required tools like `jq` and `curl` if you encounter errors regarding missing commands.

- **Ollama API Errors**:
  - Verify that the Ollama server is running at the specified host and port.
  - Check network connectivity and firewall settings if you are unable to connect.

- **Empty Diff**:
  - Make sure that there are staged changes before executing the script.

---

## License

Distributed under the MIT License.


