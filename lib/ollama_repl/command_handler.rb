# frozen_string_literal: true

require "pathname" # For File operations in handle_file_command

module OllamaRepl
  class CommandHandler
    def initialize(repl, context_manager, io_service)
      @repl = repl
      @context_manager = context_manager
      @io_service = io_service
    end

    # Handles command input (e.g., "/help", "/model llama3")
    def handle(input)
      parts = input.split(" ", 2)
      command = parts[0].downcase
      args = parts[1]

      # Debugging output (optional)
      # puts "[CommandHandler] Handling command: '#{command}', args: '#{args}'"

      case command
      when "/llm"
        handle_llm_command(args)
      when "/ruby"
        handle_ruby_command(args)
      when "/shell"
        handle_shell_command(args)
      when "/file"
        handle_file_command(args)
      when "/model"
        handle_model_command(args)
      when "/context"
        display_context
      when "/clear"
        clear_context
      when "/help"
        display_help
      when "/exit", "/quit"
        # Handled in main loop, but good practice to acknowledge
        @io_service.display("Exiting.")
        exit 0
      else
        @io_service.display("Unknown command: #{command}. Type /help for available commands.")
      end
    end

    private

    # --- Command Implementation Methods (To be moved from Repl) ---

    def handle_llm_command(args)
      if args && !args.empty?
        @repl.run_in_mode(:llm, args) # Use run_in_mode for one-off execution
      else
        @repl.switch_mode(:llm) # Use symbol for durable mode switch
      end
    end

    def handle_ruby_command(args)
      if args && !args.empty?
        @repl.run_in_mode(:ruby, args) # Use run_in_mode for one-off execution
      else
        @repl.switch_mode(:ruby) # Use symbol for durable mode switch
      end
    end

    def handle_shell_command(args)
      if args && !args.empty?
        @repl.run_in_mode(:shell, args) # Use run_in_mode for one-off execution
      else
        @repl.switch_mode(:shell) # Use symbol for durable mode switch
      end
    end

    def handle_file_command(args)
      unless args && !args.empty?
        @io_service.display("Usage: /file {file_path}")
        return
      end
      file_path = File.expand_path(args)
      unless File.exist?(file_path)
        @io_service.display_error("File not found: #{file_path}")
        return
      end
      unless File.readable?(file_path)
        @io_service.display_error("Cannot read file (permission denied): #{file_path}")
        return
      end

      begin
        content = File.read(file_path)
        extension = File.extname(file_path).downcase
        # Access constant via the class name now that Repl instance doesn't define MODE_* constants
        lang = OllamaRepl::Repl::FILE_TYPE_MAP[extension] || "" # Get lang identifier or empty string

        formatted_content = "System Message: File Content (#{File.basename(file_path)})\n"
        formatted_content += "```#{lang}\n"
        formatted_content += content
        formatted_content += "\n```"

        @repl.add_message("system", formatted_content)
        @io_service.display("Added content from #{File.basename(file_path)} to context.")
      rescue => e
        @io_service.display_error("Error reading file #{file_path}: #{e.message}")
      end
    end

    def handle_model_command(args)
      # Use our cached models for consistent behavior with tab completion
      debug_enabled = ENV["DEBUG"] == "true"
      available_models = @repl.get_available_models(debug_enabled)

      if args.nil? || args.empty?
        # List models
        if available_models.empty?
          @io_service.display("No models available on the Ollama host.")
        else
          @io_service.display("Available models:")
          available_models.each { |m| @io_service.display("- #{m}") }
          @io_service.display("\nCurrent model: #{@repl.client.current_model}")
          @io_service.display("\nTip: Type '/model' followed by at least 3 characters and press Tab for autocompletion")
        end
        return
      end

      # Set model
      target_model = args.strip
      exact_match = available_models.find { |m| m == target_model }
      prefix_matches = available_models.select { |m| m.start_with?(target_model) }

      chosen_model = nil
      if exact_match
        chosen_model = exact_match
      elsif prefix_matches.length == 1
        chosen_model = prefix_matches.first
      elsif prefix_matches.length > 1
        @io_service.display("Ambiguous model name '#{target_model}'. Matches:")
        prefix_matches.each { |m| @io_service.display("- #{m}") }
        return
      else
        @io_service.display_error("Model '#{target_model}' not found.")
        if available_models.any?
          @io_service.display("Available models: #{available_models.join(", ")}")
        end
        return
      end

      if chosen_model
        @repl.client.update_model(chosen_model)
        @io_service.display("Model set to '#{chosen_model}'.")
        # Optionally, clear context when changing model? Or inform user context is kept.
        # @io_service.display("Conversation context remains.")
      end
    rescue Client::ApiError => e
      @io_service.display_api_error("Error managing models: #{e.message}")
    end

    def display_context
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

    def clear_context
      @io_service.display("Are you sure you want to clear the conversation history? (y/N): ")
      confirmation = $stdin.gets.chomp.downcase # Direct stdin usage needed here
      if confirmation == "y"
        @context_manager.clear
        @io_service.display("Conversation context cleared.")
      else
        @io_service.display("Clear context cancelled.")
      end
    end

    def display_help
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
