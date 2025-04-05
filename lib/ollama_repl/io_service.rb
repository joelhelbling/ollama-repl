# frozen_string_literal: true

require "readline"

module OllamaRepl
  # Service class for handling all input/output operations
  # This provides a consistent interface for terminal interactions
  # and improves testability by allowing I/O mocking
  class IOService
    # Display a message to the user
    # @param message [String] The message to display
    def display(message)
      puts message
    end

    # Display an error message with standard formatting
    # @param message [String] The error message
    def display_error(message)
      puts "[Error] #{message}"
    end

    # Display an API error message
    # @param message [String] The API error message
    def display_api_error(message)
      puts "[API Error] #{message}"
    end

    # Display a detailed execution error with optional stack trace
    # @param context [String] The execution context (e.g., "ruby", "shell")
    # @param error [Exception] The error object
    def display_execution_error(context, error)
      puts "[Unexpected Error during #{context} execution] #{error.class}: #{error.message}"
      puts error.backtrace.join("\n") if ENV["DEBUG"]
    end

    # Prompt the user for input
    # @param prompt_text [String] The prompt text to display
    # @param add_to_history [Boolean] Whether to add the input to Readline history
    # @return [String, nil] The user's input, or nil if end-of-file
    def prompt(prompt_text, add_to_history = true)
      Readline.readline(prompt_text, add_to_history)
    end

    # Display a debug message if debugging is enabled
    # @param message [String] The debug message
    # @param debug_enabled [Boolean] Whether debugging is enabled
    def debug(message, debug_enabled = false)
      puts message if debug_enabled
    end

    # Exit the application with an error message
    # @param message [String] The error message to display before exiting
    # @param exit_code [Integer] The exit code (defaults to 1)
    def exit_with_error(message, exit_code = 1)
      display_error(message)
      exit exit_code
    end
  end
end
