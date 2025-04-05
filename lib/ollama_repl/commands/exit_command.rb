# frozen_string_literal: true

require_relative "command"

module OllamaRepl
  module Commands
    class ExitCommand < Command
      def initialize(io_service)
        @io_service = io_service
      end

      def execute(args, context)
        @io_service.display("Exiting.")
        exit 0
      end
    end
  end
end
