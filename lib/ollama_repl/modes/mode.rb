# frozen_string_literal: true

module OllamaRepl
  module Modes
    # Base class/interface for different REPL modes.
    # Concrete mode classes should inherit from this class
    # and implement the required methods.
    class Mode
      # Initializes the mode, potentially storing references
      # to shared resources like the client or context manager if needed
      # directly by the mode instance.
      def initialize(client, context_manager)
        @client = client
        @context_manager = context_manager
      end

      # Handles the user input for this specific mode.
      #
      # @param input [String] The user's input line.
      # @param context_manager [ContextManager] The conversation context manager.
      # @param client [Client] The Ollama API client.
      # @return [void]
      def handle_input(input)
        raise NotImplementedError, "#{self.class.name} must implement #handle_input"
      end

      # Returns the prompt string to display for this mode.
      #
      # @return [String] The prompt string (e.g., "🤖 ❯ ").
      def prompt
        raise NotImplementedError, "#{self.class.name} must implement #prompt"
      end

      protected

      # Helper method to add messages to the context.
      # Provides a consistent way for modes to interact with context.
      def add_message(role, content)
        @context_manager.add(role, content)
      end
    end
  end
end
