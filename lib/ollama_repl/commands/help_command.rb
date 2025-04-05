# frozen_string_literal: true

require_relative "command"

module OllamaRepl
  module Commands
    class HelpCommand < Command
      def initialize(io_service, command_registry)
        @io_service = io_service
        @command_registry = command_registry
      end

      def execute(args, context)
        @io_service.display("\n--- Ollama REPL Help ---")
        @io_service.display("Modes:")
        @io_service.display("  /llm           Switch to durable LLM interaction mode (default).")
        @io_service.display("  /ruby          Switch to durable Ruby execution mode.")
        @io_service.display("  /shell         Switch to durable Shell execution mode.")
        @io_service.display("")

        @io_service.display("One-off Actions (stay in current durable mode):")
        @io_service.display("  /llm {prompt}  Send a single prompt to the LLM.")
        @io_service.display("  /ruby {code}   Execute a single line of Ruby code.")
        @io_service.display("  /shell {command} Execute a single shell command.")
        @io_service.display("")

        @io_service.display("Commands:")
        @io_service.display("  /file {path}   Add the content of the specified file to the context.")
        @io_service.display("  /model         List available Ollama models.")
        @io_service.display("  /model {name}  Switch to the specified Ollama model (allows prefix matching).")
        @io_service.display("                 Type at least 3 characters after '/model ' and press Tab for autocompletion.")
        @io_service.display("  /context       Display the current conversation context.")
        @io_service.display("  /clear         Clear the conversation context (asks confirmation).")
        @io_service.display("  /help          Show this help message.")
        @io_service.display("  /exit, /quit   Exit the REPL.")
        @io_service.display("  Ctrl+C         Interrupt current action (or show exit hint).")
        @io_service.display("  Ctrl+D         Exit the REPL (at empty prompt).")
        @io_service.display("------------------------\n")
      end
    end
  end
end
