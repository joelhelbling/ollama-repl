# Ruby Ollama REPL Gem

## Core Goal
Create a Ruby Gem that provides a terminal-based REPL (Read-Eval-Print Loop) chat interface for interacting with an Ollama API. The program should maintain a conversation history (`messages` context) and allow switching between interacting with the Ollama LLM and executing Ruby code locally.

## Project Structure & Packaging
- Generate a standard Ruby Gem structure.
- Include a `.gemspec` file named `ollama_repl.gemspec`.
    - Include placeholder metadata (name: `ollama_repl`, version: `0.1.0`, author, email, summary, description, license: MIT).
    - Declare `faraday` and `dotenv` as runtime dependencies.
    - Declare `readline` as a runtime dependency (for better REPL experience).
- Include an executable file in `bin/ollama-repl`.
- The main library code should reside in `lib/ollama_repl.rb` and potentially supporting files within `lib/ollama_repl/`.

## Configuration
- Use environment variables, loaded from a `.env` file in the project root if present (use the `dotenv` gem).
- Required Environment Variables:
    - `OLLAMA_HOST`: The base URL of the Ollama API (e.g., `http://localhost:11434`). Provide a sensible default if not set (e.g., `http://localhost:11434`).
    - `OLLAMA_MODEL`: The default Ollama model to use (e.g., `llama3`). The program should fail gracefully with a clear message if this is not set and no default is appropriate or available via the API initially.
- Ensure the API host URL is handled correctly (e.g., ensuring no double slashes when appending paths).

## Ollama Interaction
- Use the Faraday Ruby gem for all HTTP communication with the Ollama API.
- Implement communication with the Ollama `/api/chat` endpoint for LLM interactions.
- Implement communication with the Ollama `/api/tags` endpoint for listing available models (`/model` command).
- Structure requests to `/api/chat` correctly, sending the `messages` array (conversation history) and the `model` name. Ensure `stream: false` is used for simplicity for now.
- Parse the JSON response from `/api/chat` to extract the assistant's reply.

## Conversation Context (`messages` History)
- Maintain an ordered list (array) representing the conversation history, compatible with the Ollama `/api/chat` endpoint's `messages` parameter (array of objects with `role` and `content` keys).
- Roles used should be `user`, `assistant`, and `system`.
- Append user inputs (from `/llm` mode and `/ruby` mode) to the `messages` array with `role: 'user'`.
- Append Ollama's responses to the `messages` array with `role: 'assistant'`.
- Append Ruby execution output (STDOUT/STDERR) and file contents (`/file` command) to the `messages` array with `role: 'system'`, clearly indicating the source (see command details).

## REPL Functionality & Input Modes
- Implement a main REPL loop using the `readline` gem for input (provides history and editing).
- The program starts in `/llm` mode by default.
- **Mode Switching:**
    - `/llm`: Enters durable LLM mode.
    - `/ruby`: Enters durable Ruby mode.
    - `/llm {prompt}`: Sends a single prompt to the LLM (stays in the current durable mode).
    - `/ruby {code}`: Executes a single line of Ruby code (stays in the current durable mode).
- **Prompts:**
    - Display `🤖 > ` when in durable `/llm` mode.
    - Display `💎 > ` when in durable `/ruby` mode.
- **`/llm` Mode:**
    - Any text entered (not matching another command) is treated as a user prompt.
    - Append the user prompt to the `messages` context (`role: 'user'`).
    - Send the *entire* `messages` context to the Ollama `/api/chat` endpoint.
    - Display the assistant's response content to the user.
    - Append the assistant's response to the `messages` context (`role: 'assistant'`).
- **`/ruby` Mode:**
    - Any text entered (not matching another command) is treated as Ruby code to be evaluated.
    - Append the entered Ruby code to the `messages` context (`role: 'user'`).
    - Execute the Ruby code using `eval` within a safe context if possible, or directly. Capture both STDOUT and STDERR.
    - Display the captured STDOUT and STDERR to the user.
    - Append the captured output to the `messages` context (`role: 'system'`). Format it clearly, e.g.:
        ```
        System Message: Ruby Execution Output
        STDOUT:
        {captured stdout}
        STDERR:
        {captured stderr}
        ```
    - Handle potential exceptions during Ruby code evaluation gracefully: display the error message to the user and append a system message containing the error details to the context.

## Additional Commands
- Implement command parsing (check if input starts with `/`).
- **`/file {file_path}`:**
    - Read the content of the specified file.
    - Handle potential errors (file not found, permission denied) gracefully with user feedback.
    - Prepend a header like `File Content ({file_path}):\n` to the file content.
    - Detect the file type (based on extension, e.g., `.rb`, `.py`, `.md`) and enclose the content in appropriate Github-style markdown code fences (e.g., ```ruby ... ```). Default to plain code fences (``` ... ```) if the type is unknown.
    - Append this formatted content string to the `messages` context with `role: 'system'`.
    - Provide feedback to the user (e.g., "Added content from {file_path} to context.").
- **`/model`:**
    - List available Ollama models by querying the `/api/tags` endpoint. Handle API errors gracefully.
    - Display the list of model names to the user.
- **`/model {model_name}`:**
    - Query `/api/tags` to get available models.
    - Attempt to match the provided `{model_name}` against the available models (allow partial prefix matching, but prefer exact matches; report ambiguity if multiple models match a prefix).
    - If a single unique model is matched, set it as the current `OLLAMA_MODEL` for subsequent `/api/chat` requests.
    - Provide feedback to the user on success (e.g., "Model set to '{matched_model_name}'") or failure (e.g., "Model '{model_name}' not found.", "Ambiguous model name, matches: ..."). Handle API errors gracefully.
- **`/context`:** (Optional but recommended)
    - Display the current `messages` history to the user for debugging/review. Format it readably.
- **`/clear`:** (Optional but recommended)
    - Clear the current `messages` history, starting a fresh conversation context. Ask for confirmation.
- **`/help`:**
    - Display a brief help message listing available modes and commands.
- **`/exit` or `/quit`:**
    - Exit the program cleanly. Also handle Ctrl+C gracefully for termination.

## Error Handling & Robustness
- Implement general error handling for API requests (connection errors, timeouts, non-200 status codes, JSON parsing errors). Provide informative messages to the user without crashing.
- Handle user input errors (e.g., invalid commands) gracefully.

## Output Format
- Return the complete Ruby code for the Gem (gemspec, executable, library files) within Github-style Ruby code fences (```ruby ... ```).
- Do not include any explanatory text outside the code fences in the final output.