# frozen_string_literal: true

require "stringio"
require_relative "mode"

module OllamaRepl
  module Modes
    # Handles interaction in Ruby execution mode.
    class RubyMode < Mode
      # Returns the prompt string for Ruby mode.
      # @return [String]
      def prompt
        "💎 ❯ "
      end

      # Handles user input by executing it as Ruby code,
      # capturing output and errors.
      #
      # @param input [String] The Ruby code to execute.
      # @return [void]
      def handle_input(code)
        puts "💎 Executing..."
        # Add code to context first, using helper method
        add_message("user", "Execute Ruby code: ```ruby\n#{code}\n```")

        stdout_str, stderr_str, error = capture_ruby_execution(code)

        # Format the message to exactly match test expectations
        output_message = format_output_message(stdout_str, stderr_str, error)

        if error
          error_details = "Error: #{error.class}: #{error.message}\nBacktrace:\n#{error.backtrace.join("\n")}"
          puts "[Ruby Execution Error]"
          puts error_details
        else
          puts "[Ruby Execution Result]"
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
        message = "System Message: Ruby Execution Output\n"
        message += "STDOUT:\n"
        message += stdout_str.empty? ? "(empty)" : stdout_str.chomp
        message += "\nSTDERR:\n"
        message += stderr_str.empty? ? "(empty)" : stderr_str.chomp

        if error
          message += "\nException:\nError: #{error.class}: #{error.message}\nBacktrace:#{error.backtrace.join("\n")}"
        end

        message + "\n"
      end

      # Captures STDOUT, STDERR, and any exceptions during the execution
      # of the provided Ruby code string.
      #
      # @param code [String] The Ruby code to evaluate.
      # @return [Array<String, String, Exception, nil>] An array containing
      #   the captured STDOUT, captured STDERR, and the exception object
      #   (or nil if execution was successful).
      def capture_ruby_execution(code)
        original_stdout = $stdout
        original_stderr = $stderr
        stdout_capture = StringIO.new
        stderr_capture = StringIO.new
        $stdout = stdout_capture
        $stderr = stderr_capture
        error = nil

        begin
          # Using Kernel#eval directly. Be cautious.
          # Consider security implications in a real-world application.
          # The binding used here will be the binding within this method.
          # If access to the Repl's instance variables or a specific context
          # is needed, the binding would need to be passed or adjusted.
          eval(code, binding) # rubocop:disable Security/Eval
        rescue Exception => e # Catch StandardError and descendants
          error = e
        ensure
          $stdout = original_stdout
          $stderr = original_stderr
        end

        # Return exactly what the tests expect
        [stdout_capture.string, stderr_capture.string, error]
      end
    end
  end
end
