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
require_relative "mode_factory"
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
      @mode_factory = dependencies[:mode_factory] || ModeFactory.new(@client, @context_manager)

      # Initialize the starting mode object
      @current_mode = dependencies[:initial_mode] || @mode_factory.create(:llm)

      # Initialize command handler with io_service
      @command_handler = dependencies[:command_handler] ||
        CommandHandler.new(self, @context_manager, @io_service)

      setup_readline
    rescue Error => e # Catch configuration or initial connection errors
      @io_service ||= IOService.new # Ensure io_service exists even if error during initialization
      @io_service.exit_with_error(e.message)
    end

    def run
      display_welcome_message
      check_initial_connection

      main_loop
    rescue Error => e # Catch connection/config errors
      handle_fatal_error(e)
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
      @current_mode = @mode_factory.create(mode_type)
      mode_name = @current_mode.class.name.split("::").last.gsub("Mode", "")
      @io_service.display("Switched to #{mode_name} mode.")
    rescue ArgumentError => e
      @io_service.display_error(e.message)
    end

    # Executes a given input in a specific mode temporarily, without changing the durable mode.
    # Used for one-off commands like `/ruby {code}`.
    # @param mode_type [Symbol] The type of mode to execute in (e.g., :llm, :ruby, :shell)
    # @param input [String] The input string to handle in the specified mode.
    def run_in_mode(mode_type, input)
      mode_instance = @mode_factory.create(mode_type)
      mode_instance.handle_input(input)
    rescue ArgumentError => e
      @io_service.display_error(e.message)
    rescue => e
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

    def display_welcome_message
      @io_service.display("Welcome to Ollama REPL!")
      @io_service.display("Using model: #{@client.current_model}")
      @io_service.display("Type `/help` for commands.")

      # Pre-cache available models
      get_available_models
    end

    def check_initial_connection
      @client.check_connection_and_model
    rescue Client::ModelNotFoundError => e
      handle_model_not_found_error(e)
    end

    def main_loop
      loop do
        result = handle_input_iteration
        break if result == :exit
      rescue Interrupt # Handle Ctrl+C
        @io_service.display("\nType /exit or /quit to leave.")
      rescue Client::ApiError => e
        @io_service.display_api_error(e.message)
      rescue => e
        @io_service.display_execution_error("general", e)
      end
    end

    def handle_input_iteration
      prompt = current_prompt
      input = @io_service.prompt(prompt)

      # Handle EOF or nil input (Ctrl+D)
      if input.nil?
        @io_service.display("\nExiting.")
        return :exit
      end

      input.strip!

      # Add non-empty input to history
      Readline::HISTORY.push(input) unless input.empty?

      # Exit commands
      return :exit if ["/exit", "/quit"].include?(input.downcase)

      process_input(input)
      :continue
    end

    def handle_fatal_error(error)
      @io_service.display_error(error.message)
      @io_service.display("Please check your OLLAMA_HOST and OLLAMA_MODEL settings and ensure Ollama is running.")
      exit 1
    end

    # setup_readline remains private implicitly
    # get_available_models was made public, keep it that way for CommandHandler
  end
end
