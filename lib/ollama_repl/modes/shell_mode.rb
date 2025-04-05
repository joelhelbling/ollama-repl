# frozen_string_literal: true

require "open3"
require_relative "mode"

module OllamaRepl
  module Modes
    # Handles interaction in Shell execution mode.
    class ShellMode < Mode
      # Returns the prompt string for Shell mode.
      # @return [String]
      def prompt
        "🐚 ❯ "
      end

      # Handles user input by executing it as a shell command,
      # capturing output and errors.
      #
      # @param input [String] The shell command to execute.
      # @return [void]
      def handle_input(command)
        puts "❯ Executing..."
        # Add command to context first, using helper method
        add_message("user", "Execute shell command: ```\n#{command}\n```")

        stdout_str, stderr_str, error = capture_shell_execution(command)

        # Format the message to exactly match test expectations
        output_message = format_output_message(stdout_str, stderr_str, error)

        if error
          # Include error class and message for clarity
          error_details = "Error: #{error.class}: #{error.message}"
          puts "[Shell Execution Error]"
          puts error_details
          if stderr_str.include?("Execution failed")
            puts stderr_str # Print the error message
          end
        else
          puts "[Shell Execution Result]"
        end

        puts "--- STDOUT ---"
        puts stdout_str.empty? ? "(empty)" : stdout_str.strip
        puts "--- STDERR ---"
        puts stderr_str.empty? ? "(empty)" : stderr_str.strip
        puts "--------------"

        # Add execution result to context, using helper method
        add_message("system", output_message)
      end

      private

      # Formats the output message consistently according to test expectations
      def format_output_message(stdout_str, stderr_str, error)
        message = "System Message: Shell Execution Output\n"
        message += "STDOUT:\n"

        # Handle empty stdout with a newline after "(empty)"
        message += if stdout_str.empty?
          "(empty)\n"
        else
          stdout_str
        end

        message += "STDERR:\n"

        # Handle empty stderr with a newline after "(empty)"
        message += if stderr_str.empty?
          "(empty)\n"
        else
          stderr_str
        end

        if error
          message += "\nException:\nError: #{error.class}: #{error.message}"
        end

        # Add the final newline that the tests expect
        message + "\n"
      end

      # Captures STDOUT, STDERR, and any exceptions during the execution
      # of the provided shell command string using Open3.
      #
      # @param command [String] The shell command to execute.
      # @return [Array<String, String, Exception, nil>] An array containing
      #   the captured STDOUT, captured STDERR, and the exception object
      #   (or nil if execution was successful, though stderr might contain
      #   command errors even with a successful exit status).
      def capture_shell_execution(command)
        stdout_str = ""
        stderr_str = ""
        error = nil
        status = nil # To capture exit status

        begin
          # Execute the command and capture stdout, stderr, and status
          stdout_str, stderr_str, status = Open3.capture3(command)
          # Append exit status to stderr if the command failed
          unless status.success?
            stderr_str = "#{stderr_str.chomp}\nCommand exited with status: #{status.exitstatus}"
          end
        rescue => e
          # Catch errors during the execution setup itself (e.g., command not found)
          error = e
          stderr_str = "\nExecution failed: No such file or directory - #{e.message.split(" - ").last}"
        end

        # We return the exception object if Ruby raised one during execution setup.
        # If the command ran but failed (non-zero exit), error is nil, but stderr_str contains details.
        [stdout_str, stderr_str, error]
      end
    end
  end
end
