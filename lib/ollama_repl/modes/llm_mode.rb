# frozen_string_literal: true

require_relative "mode"
require_relative "../client" # For Client::ApiError

module OllamaRepl
  module Modes
    # Handles interaction in LLM mode.
    class LlmMode < Mode
      # Returns the prompt string for LLM mode.
      # @return [String]
      def prompt
        "🤖 ❯ "
      end

      # Handles user input by sending it to the LLM via the client
      # and streaming the response.
      #
      # @param input [String] The user's input prompt.
      # @return [void]
      def handle_input(input)
        add_message("user", input) # Use protected helper from base Mode
        full_response = String.new
        $stdout.print "\nAssistant: " # Print prefix once using $stdout directly for testability

        begin
          @client.chat(@context_manager.for_api) do |chunk|
            content_part = chunk.dig("message", "content")
            unless content_part.nil? || content_part.empty?
              $stdout.print content_part # Stream output directly using $stdout for testability
              $stdout.flush
              full_response << content_part
            end
            # Optional: Handle chunk['done'] if needed
          end
          puts "" # Final newline after streaming

          # Add complete response to context
          add_message("assistant", full_response) unless full_response.empty?
        rescue Client::ApiError => e
          # Error handling remains similar, using instance variables
          puts "\n[API Error interacting with LLM] #{e.message}"
          # Consider if context manipulation is needed here (e.g., removing failed user message)
        ensure
          # Ensure a newline even if there was an error during streaming
          puts "" unless full_response.empty? && !$stdout.tty? # Avoid extra newline if nothing printed and not interactive
        end
      end
    end
  end
end
