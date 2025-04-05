# frozen_string_literal: true

require_relative "command"

module OllamaRepl
  module Commands
    class ContextCommand < Command
      def initialize(context_manager, io_service)
        @context_manager = context_manager
        @io_service = io_service
      end

      def execute(args, context)
        @io_service.display("\n--- Conversation Context ---")
        if @context_manager.empty?
          @io_service.display("(empty)")
        else
          @context_manager.all.each_with_index do |msg, index|
            @io_service.display("[#{index + 1}] #{msg[:role].capitalize}:")
            @io_service.display(msg[:content])
            @io_service.display("---")
          end
        end
        @io_service.display("Total messages: #{@context_manager.length}")
        @io_service.display("--------------------------\n")
      end
    end
  end
end
