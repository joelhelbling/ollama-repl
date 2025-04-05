# frozen_string_literal: true

require_relative "command_registry"
require_relative "commands/command"
require_relative "commands/help_command"
require_relative "commands/llm_command"
require_relative "commands/ruby_command"
require_relative "commands/shell_command"
require_relative "commands/file_command"
require_relative "commands/model_command"
require_relative "commands/context_command"
require_relative "commands/clear_command"
require_relative "commands/exit_command"

module OllamaRepl
  class CommandHandler
    def initialize(repl, context_manager, io_service)
      @repl = repl
      @context_manager = context_manager
      @io_service = io_service
      @registry = CommandRegistry.new

      # Register commands
      setup_commands
    end

    # Handles command input (e.g., "/help", "/model llama3")
    def handle(input)
      parts = input.split(" ", 2)
      command_name = parts[0].downcase
      args = parts[1]

      if @registry.has_command?(command_name)
        command = @registry.get_command(command_name)
        context = {
          repl: @repl,
          context_manager: @context_manager,
          io_service: @io_service
        }
        command.execute(args, context)
      else
        @io_service.display("Unknown command: #{command_name}. Type /help for available commands.")
      end
    end

    private

    def setup_commands
      @registry.register("/help", Commands::HelpCommand.new(@io_service, @registry))
      @registry.register("/llm", Commands::LlmCommand.new(@repl, @io_service))
      @registry.register("/ruby", Commands::RubyCommand.new(@repl, @io_service))
      @registry.register("/shell", Commands::ShellCommand.new(@repl, @io_service))
      @registry.register("/file", Commands::FileCommand.new(@repl, @io_service))
      @registry.register("/model", Commands::ModelCommand.new(@repl, @io_service))
      @registry.register("/context", Commands::ContextCommand.new(@context_manager, @io_service))
      @registry.register("/clear", Commands::ClearCommand.new(@context_manager, @io_service))

      # Register exit commands
      exit_command = Commands::ExitCommand.new(@io_service)
      @registry.register("/exit", exit_command)
      @registry.register("/quit", exit_command)
    end
  end
end
