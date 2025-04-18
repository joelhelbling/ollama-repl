# Refactoring Plan: Extract CommandHandler from Repl

This document outlines the plan to extract command handling logic from `lib/ollama_repl/repl.rb` into a new `OllamaRepl::CommandHandler` class.

**Goal:** Improve separation of concerns, readability, and maintainability by isolating command processing logic.

**Approach:** Create a dedicated `CommandHandler` class and delegate command processing to it from the main `Repl` class. For simplicity in this initial step, the `CommandHandler` will receive the entire `Repl` instance upon initialization.

**Steps:**

1.  **Create New File:**
    *   Create the file `lib/ollama_repl/command_handler.rb`.

2.  **Define `OllamaRepl::CommandHandler` Class:**
    *   Location: `lib/ollama_repl/command_handler.rb`
    *   **`initialize(repl)`:**
        *   Accepts an instance of the `Repl` class.
        *   Stores the `repl` instance in an instance variable (e.g., `@repl`).
    *   **`handle(input)` Method:**
        *   Public method, the main entry point for command processing.
        *   Takes the raw command input string (e.g., "/model llama3") as an argument.
        *   Parses the input into `command` (e.g., "/model") and `args` (e.g., "llama3").
        *   Uses a `case` statement based on the `command` to dispatch to private helper methods within the `CommandHandler`.
    *   **Private Helper Methods:**
        *   Implement the specific logic for each command currently handled by `Repl#handle_command` and its associated methods (`handle_file_command`, `handle_model_command`, `display_context`, `clear_context`, `display_help`).
        *   These methods will interact with the `Repl` instance via the stored `@repl` variable (e.g., calling `@repl.client`, `@repl.messages`, `@repl.add_message`, `@repl.switch_mode`, `@repl.get_available_models`, `@repl.puts`, etc.).
        *   Example methods: `handle_llm_command(args)`, `handle_ruby_command(args)`, `handle_shell_command(args)`, `handle_file_command(args)`, `handle_model_command(args)`, `display_context`, `clear_context`, `display_help`.

3.  **Modify `lib/ollama_repl/repl.rb`:**
    *   **Require New File:** Add `require_relative 'command_handler'` near the top of the file.
    *   **Instantiate `CommandHandler`:** In the `Repl#initialize` method, create and store an instance of the new handler:
        ```ruby
        @command_handler = OllamaRepl::CommandHandler.new(self)
        ```
    *   **Update `Repl#process_input`:** Modify the method to delegate command processing:
        ```ruby
        def process_input(input)
          return if input.empty?

          if input.start_with?('/')
            @command_handler.handle(input) # Delegate to the handler
          else
            # Existing mode-specific handling remains here for now
            case @mode
            when MODE_LLM
              handle_llm_input(input)
            when MODE_RUBY
              handle_ruby_input(input)
            when MODE_SHELL
              handle_shell_input(input)
            end
          end
        end
        ```
    *   **Remove Redundant Methods:** Delete the following methods from the `Repl` class, as their logic is now encapsulated within `CommandHandler`:
        *   `handle_command`
        *   `handle_file_command`
        *   `handle_model_command`
        *   `display_context`
        *   `clear_context`
        *   `display_help`
        *   *(Note: Methods like `add_message`, `switch_mode`, `get_available_models`, `handle_llm_input`, etc., remain in `Repl` as they are still needed by the handler or the main loop).*

**Next Steps:**

*   Implement the changes described above.
*   Test the REPL thoroughly to ensure all commands function correctly after the refactoring.
*   Consider further refactoring steps (e.g., refining dependencies, extracting other responsibilities) once this initial extraction is complete and verified.