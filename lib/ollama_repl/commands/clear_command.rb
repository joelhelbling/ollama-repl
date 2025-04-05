# frozen_string_literal: true

require_relative "command"

module OllamaRepl
  module Commands
    class ClearCommand < Command
      def initialize(context_manager, io_service)
        @context_manager = context_manager
        @io_service = io_service
      end

      def execute(args, context)
        @io_service.display("Are you sure you want to clear the conversation history? (y/N): ")
        confirmation = $stdin.gets.chomp.downcase # Direct stdin usage needed here
        if confirmation == "y"
          @context_manager.clear
          @io_service.display("Conversation context cleared.")
        else
          @io_service.display("Clear context cancelled.")
        end
      end
    end
  end
end
