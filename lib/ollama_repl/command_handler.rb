# frozen_string_literal: true

require 'pathname' # For File operations in handle_file_command

module OllamaRepl
  class CommandHandler
    def initialize(repl, context_manager)
      @repl = repl
      @context_manager = context_manager
    end

    # Handles command input (e.g., "/help", "/model llama3")
    def handle(input)
      parts = input.split(' ', 2)
      command = parts[0].downcase
      args = parts[1]

      # Debugging output (optional)
      # puts "[CommandHandler] Handling command: '#{command}', args: '#{args}'"

      case command
      when '/llm'
        handle_llm_command(args)
      when '/ruby'
        handle_ruby_command(args)
      when '/shell'
        handle_shell_command(args)
      when '/file'
        handle_file_command(args)
      when '/model'
        handle_model_command(args)
      when '/context'
        display_context
      when '/clear'
        clear_context
      when '/help'
        display_help
      when '/exit', '/quit'
        # Handled in main loop, but good practice to acknowledge
        puts "Exiting." # Direct puts call since Repl doesn't have a puts method
        exit 0
      else
        puts "Unknown command: #{command}. Type /help for available commands."
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
        puts "Usage: /file {file_path}"
        return
      end
      file_path = File.expand_path(args)
      unless File.exist?(file_path)
        puts "Error: File not found: #{file_path}"
        return
      end
      unless File.readable?(file_path)
        puts "Error: Cannot read file (permission denied): #{file_path}"
        return
      end

      begin
        content = File.read(file_path)
        extension = File.extname(file_path).downcase
        # Access constant via the class name now that Repl instance doesn't define MODE_* constants
        lang = OllamaRepl::Repl::FILE_TYPE_MAP[extension] || '' # Get lang identifier or empty string

        formatted_content = "System Message: File Content (#{File.basename(file_path)})\n"
        formatted_content += "```#{lang}\n"
        formatted_content += content
        formatted_content += "\n```"

        @repl.add_message('system', formatted_content)
        puts "Added content from #{File.basename(file_path)} to context."

      rescue StandardError => e
        puts "Error reading file #{file_path}: #{e.message}"
      end
    end

    def handle_model_command(args)
      # Use our cached models for consistent behavior with tab completion
      debug_enabled = ENV['DEBUG'] == 'true'
      available_models = @repl.get_available_models(debug_enabled)

      if args.nil? || args.empty?
        # List models
        if available_models.empty?
            puts "No models available on the Ollama host."
        else
            puts "Available models:"
            available_models.each { |m| puts "- #{m}" }
            puts "\nCurrent model: #{@repl.client.current_model}"
            puts "\nTip: Type '/model' followed by at least 3 characters and press Tab for autocompletion"
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
        puts "Ambiguous model name '#{target_model}'. Matches:"
        prefix_matches.each { |m| puts "- #{m}" }
        return
      else
        puts "Model '#{target_model}' not found."
        if available_models.any?
          puts "Available models: #{available_models.join(', ')}"
        end
        return
      end

      if chosen_model
        @repl.client.update_model(chosen_model)
        puts "Model set to '#{chosen_model}'."
        # Optionally, clear context when changing model? Or inform user context is kept.
        # puts "Conversation context remains."
      end

    rescue Client::ApiError => e
       puts "[API Error managing models] #{e.message}"
    end

    def display_context
      puts "\n--- Conversation Context ---"
      if @context_manager.empty?
        puts "(empty)"
      else
        @context_manager.all.each_with_index do |msg, index|
          puts "[#{index + 1}] #{msg[:role].capitalize}:"
          puts msg[:content]
          puts "---"
        end
      end
      puts "Total messages: #{@context_manager.length}"
      puts "--------------------------\n"
    end

    def clear_context
      print "Are you sure you want to clear the conversation history? (y/N): "
      confirmation = $stdin.gets.chomp.downcase # Use $stdin here, not Readline
      if confirmation == 'y'
        @context_manager.clear
        puts "Conversation context cleared."
      else
        puts "Clear context cancelled."
      end
    end

    def display_help
      puts "\n--- Ollama REPL Help ---"
      puts "Modes:"
      puts "  /llm           Switch to durable LLM interaction mode (default)."
      puts "  /ruby          Switch to durable Ruby execution mode."
      puts "  /shell         Switch to durable Shell execution mode."
      puts

      puts "One-off Actions (stay in current durable mode):"
      puts "  /llm {prompt}  Send a single prompt to the LLM."
      puts "  /ruby {code}   Execute a single line of Ruby code."
      puts "  /shell {command} Execute a single shell command."
      puts

      puts "Commands:"
      puts "  /file {path}   Add the content of the specified file to the context."
      puts "  /model         List available Ollama models."
      puts "  /model {name}  Switch to the specified Ollama model (allows prefix matching)."
      puts "                 Type at least 3 characters after '/model ' and press Tab for autocompletion."
      puts "  /context       Display the current conversation context."
      puts "  /clear         Clear the conversation context (asks confirmation)."
      puts "  /help          Show this help message."
      puts "  /exit, /quit   Exit the REPL."
      puts "  Ctrl+C         Interrupt current action (or show exit hint)."
      puts "  Ctrl+D         Exit the REPL (at empty prompt)."
      puts "------------------------\n"
    end
  end
end