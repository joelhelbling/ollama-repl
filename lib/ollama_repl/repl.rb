# frozen_string_literal: true

require "open3"
require "readline"
require "stringio"
require "pathname"
require_relative "config"
require_relative "client"
require_relative "model_cache_service"
require_relative "command_handler"
require_relative "context_manager"
require_relative "io_service"
require_relative "modes/mode" # Base mode
require_relative "modes/llm_mode"
require_relative "modes/ruby_mode"
require_relative "modes/shell_mode"

module OllamaRepl
  class Repl
    # Make client and context_manager accessible to the CommandHandler
    attr_reader :client, :context_manager
    # Mode constants removed, using symbols like :llm, :ruby, :shell

    FILE_TYPE_MAP = {
      ".rb" => "ruby", ".js" => "javascript", ".py" => "python", ".java" => "java",
      ".c" => "c", ".cpp" => "cpp", ".cs" => "csharp", ".go" => "go", ".html" => "html",
      ".css" => "css", ".json" => "json", ".xml" => "xml", ".yaml" => "yaml",
      ".yml" => "yaml", ".sh" => "bash", ".sql" => "sql", ".md" => "markdown",
      ".txt" => "" # Plain text, use default ```
    }.freeze

    def initialize(dependencies = {})
      Config.validate_config!
      @client = dependencies[:client] || Client.new(Config.ollama_host, Config.ollama_model)
      @context_manager = dependencies[:context_manager] || ContextManager.new
      @io_service = dependencies[:io_service] || IOService.new
      @model_cache_service = dependencies[:model_cache_service] || ModelCacheService.new(@client)

      # Initialize the starting mode object
      @current_mode = Modes::LlmMode.new(@client, @context_manager)

      # Initialize command handler with io_service
      @command_handler = dependencies[:command_handler] ||
        CommandHandler.new(self, @context_manager, @io_service)

      setup_readline
    rescue Error => e # Catch configuration or initial connection errors
      @io_service ||= IOService.new # Ensure io_service exists even if error during initialization
      @io_service.exit_with_error(e.message)
    end

    def run
      @io_service.display("Welcome to Ollama REPL!")
      @io_service.display("Using model: #{@client.current_model}")
      @io_service.display("Type `/help` for commands.")

      # Pre-cache available models
      get_available_models

      # Check initial connection and model validity
      begin
        @client.check_connection_and_model
      rescue Client::ModelNotFoundError => e
        # Handle the specific case where the configured model is not found
        handle_model_not_found_error(e)
      rescue Error => e # Catch other connection/config errors
        @io_service.display_error(e.message)
        @io_service.display("Please check your OLLAMA_HOST and OLLAMA_MODEL settings and ensure Ollama is running.")
        exit 1
      end

      loop do
        prompt = current_prompt
        input = @io_service.prompt(prompt)

        # Handle Ctrl+D (EOF) or empty input gracefully
        if input.nil?
          @io_service.display("\nExiting.")
          break
        end

        input.strip!

        # Add non-empty input to history (filter out commands for history clarity if desired)
        Readline::HISTORY.push(input) unless input.empty?

        # Exit commands
        break if ["/exit", "/quit"].include?(input.downcase)

        process_input(input)
      rescue Interrupt # Handle Ctrl+C
        @io_service.display("\nType /exit or /quit to leave.")
      rescue Client::ApiError => e
        @io_service.display_api_error(e.message)
      rescue => e
        @io_service.display_execution_error("general", e)
      end
    end

    # Delegate to model cache service
    def get_available_models(debug_enabled = false)
      @model_cache_service.get_models(debug_enabled: debug_enabled)
    end

    def handle_model_not_found_error(error)
      @io_service.display_error(error.message)
      @io_service.display("Available models: #{error.available_models.join(", ")}")
      @io_service.display("Please select an available model using the command: /model {model_name}")
    end

    def setup_readline
      # No longer need to initialize model cache variables here

      Readline.completion_proc = proc do |input|
        # Don't log anything by default to avoid interfering with the UI
        debug_enabled = ENV["DEBUG"] == "true"

        begin
          # Get the current input line
          line = Readline.line_buffer

          # Determine if this is a model completion context
          if line.start_with?("/model ")
            # Get what the user has typed after "/model "
            partial_name = line[7..-1] || ""

            # Debug output
            @io_service.debug("Model completion: line='#{line}', input='#{input}', partial='#{partial_name}'", debug_enabled)

            # Only activate completion after 3 chars
            if partial_name.length >= 3
              # Get available models (with caching)
              models = get_available_models(debug_enabled)

              # Find matching models
              matches = models.select { |model| model.start_with?(partial_name) }
              @io_service.debug("Found #{matches.size} matches: #{matches.inspect}", debug_enabled)

              if matches.empty?
                []
              else
                # For prefix completion, we need to return the full names
                matches
              end
            else
              []
            end
          else
            []
          end
        rescue => e
          @io_service.debug("Error in completion handler: #{e.message}", debug_enabled)
          @io_service.debug(e.backtrace.join("\n"), debug_enabled)
          []
        end
      end

      # Set the character that gets appended after completion
      Readline.completion_append_character = " "
    end

    # Delegates prompt generation to the current mode object.
    def current_prompt
      @current_mode.prompt
    end

    def process_input(input)
      return if input.empty?

      if input.start_with?("/")
        @command_handler.handle(input) # Delegate commands
      else
        # Delegate non-command input to the current mode object
        @current_mode.handle_input(input)
      end
    end

    # The command handling methods have been moved to CommandHandler
    # Keeping switch_mode and other support methods needed by CommandHandler

    # Switches the durable REPL mode.
    # @param mode_type [Symbol] The type of mode to switch to (e.g., :llm, :ruby, :shell)
    def switch_mode(mode_type)
      new_mode_instance = case mode_type
      when :llm
        Modes::LlmMode.new(@client, @context_manager)
      when :ruby
        Modes::RubyMode.new(@client, @context_manager)
      when :shell
        Modes::ShellMode.new(@client, @context_manager)
      else
        @io_service.display_error("Unknown mode type '#{mode_type}'")
        return # Don't switch if mode is unknown
      end

      @current_mode = new_mode_instance
      # Use the new mode's prompt to get the name implicitly
      mode_name = @current_mode.class.name.split("::").last.gsub("Mode", "")
      @io_service.display("Switched to #{mode_name} mode.")
    end

    # Executes a given input in a specific mode temporarily, without changing the durable mode.
    # Used for one-off commands like `/ruby {code}`.
    # @param mode_type [Symbol] The type of mode to execute in (e.g., :llm, :ruby, :shell)
    # @param input [String] The input string to handle in the specified mode.
    def run_in_mode(mode_type, input)
      mode_instance = case mode_type
      when :llm
        Modes::LlmMode.new(@client, @context_manager)
      when :ruby
        Modes::RubyMode.new(@client, @context_manager)
      when :shell
        Modes::ShellMode.new(@client, @context_manager)
      else
        @io_service.display_error("Cannot run in unknown mode type '#{mode_type}'")
        return
      end
      mode_instance.handle_input(input)
    rescue => e # Catch errors during temporary execution
      @io_service.display_execution_error(mode_type.to_s, e)
    end

    # Public method still needed by CommandHandler for /file command
    # Consider refactoring CommandHandler later to use ContextManager directly if appropriate.
    def add_message(role, content)
      @context_manager.add(role, content)
    end

    # Old handle_llm_input, handle_ruby_input, handle_shell_input,
    # capture_ruby_execution, and capture_shell_execution methods
    # are removed as their logic is now within the respective Mode classes.

    # Private methods below (if any were previously defined)
    private

    # setup_readline remains private implicitly
    # get_available_models was made public, keep it that way for CommandHandler
  end
end
