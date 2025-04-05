# frozen_string_literal: true

require_relative "command"

module OllamaRepl
  module Commands
    class ShellCommand < Command
      def initialize(repl, io_service)
        @repl = repl
        @io_service = io_service
      end

      def execute(args, context)
        if args && !args.empty?
          @repl.run_in_mode(:shell, args) # Use run_in_mode for one-off execution
        else
          @repl.switch_mode(:shell) # Use symbol for durable mode switch
        end
      end
    end
  end
end
