# frozen_string_literal: true
require 'open3'
require 'readline'
require 'stringio'
require 'pathname'
require_relative 'config'
require_relative 'client'
require_relative 'command_handler'
require_relative 'context_manager'
require_relative 'modes/mode' # Base mode
require_relative 'modes/llm_mode'
require_relative 'modes/ruby_mode'
require_relative 'modes/shell_mode'

module OllamaRepl
  class Repl
    # Make client and context_manager accessible to the CommandHandler
    attr_reader :client, :context_manager
    # Mode constants removed, using symbols like :llm, :ruby, :shell

    FILE_TYPE_MAP = {
      '.rb' => 'ruby', '.js' => 'javascript', '.py' => 'python', '.java' => 'java',
      '.c' => 'c', '.cpp' => 'cpp', '.cs' => 'csharp', '.go' => 'go', '.html' => 'html',
      '.css' => 'css', '.json' => 'json', '.xml' => 'xml', '.yaml' => 'yaml',
      '.yml' => 'yaml', '.sh' => 'bash', '.sql' => 'sql', '.md' => 'markdown',
      '.txt' => '' # Plain text, use default ```
    }.freeze

    def initialize
      Config.validate_config!
      @client = Client.new(Config.ollama_host, Config.ollama_model)
      @context_manager = ContextManager.new
      # Initialize the starting mode object
      @current_mode = Modes::LlmMode.new(@client, @context_manager)
      @command_handler = CommandHandler.new(self, @context_manager)
      setup_readline
    rescue Error => e # Catch configuration or initial connection errors
      puts "[Error] #{e.message}"
      exit 1
    end

    def run
      puts "Welcome to Ollama REPL!"
      puts "Using model: #{@client.current_model}"
      puts "Type `/help` for commands."
      
      # Pre-cache available models
      get_available_models

      # Check initial connection and model validity
      begin
        @client.check_connection_and_model
      rescue Client::ModelNotFoundError => e
        # Handle the specific case where the configured model is not found
        puts "[Error] #{e.message}" # The error message already explains the model wasn't found
        puts "Available models: #{e.available_models.join(', ')}"
        puts "Please select an available model using the command: /model {model_name}"
        # Do not exit here, allow the user to change the model
      rescue Error => e # Catch other connection/config errors
        puts "[Error] #{e.message}"
        puts "Please check your OLLAMA_HOST and OLLAMA_MODEL settings and ensure Ollama is running."
        exit 1
      end

      loop do
        prompt = current_prompt
        input = Readline.readline(prompt, true)

        # Handle Ctrl+D (EOF) or empty input gracefully
        if input.nil?
          puts "\nExiting."
          break
        end

        input.strip!

        # Add non-empty input to history (filter out commands for history clarity if desired)
        Readline::HISTORY.push(input) unless input.empty? # or: unless input.empty? || input.start_with?('/')

        # Exit commands
        break if ['/exit', '/quit'].include?(input.downcase)

        process_input(input)

      rescue Interrupt # Handle Ctrl+C
        puts "\nType /exit or /quit to leave."
      rescue Client::ApiError => e
        puts "[API Error] #{e.message}"
      rescue StandardError => e
        puts "[Unexpected Error] #{e.class}: #{e.message}"
        puts e.backtrace.join("\n") if ENV['DEBUG']
      end
    end

    # Make get_available_models public so CommandHandler can use it
    def get_available_models(debug_enabled = false)
      current_time = Time.now
      
      # Cache models for 5 minutes to avoid excessive API calls
      if @available_models_cache.nil? || @last_cache_time.nil? ||
         (current_time - @last_cache_time) > 300 # 5 minutes
        
        puts "Refreshing models cache" if debug_enabled
        begin
          @available_models_cache = @client.list_models.sort
          @last_cache_time = current_time
          puts "Cache updated with #{@available_models_cache.size} models" if debug_enabled
        rescue => e
          puts "Error fetching models: #{e.message}" if debug_enabled
          @available_models_cache ||= []
        end
      else
        puts "Using cached models (#{@available_models_cache.size})" if debug_enabled
      end
      
      @available_models_cache
    end

    def setup_readline
      # Cache for available models to improve performance
      @available_models_cache = nil
      @last_cache_time = nil
      
      Readline.completion_proc = proc do |input|
        # Don't log anything by default to avoid interfering with the UI
        debug_enabled = ENV['DEBUG'] == 'true'
        
        begin
          # Get the current input line
          line = Readline.line_buffer
          
          # Determine if this is a model completion context
          if line.start_with?('/model ')
            # Get what the user has typed after "/model "
            partial_name = line[7..-1] || ""
            
            # Debug output
            puts "Model completion: line='#{line}', input='#{input}', partial='#{partial_name}'" if debug_enabled
            
            # Only activate completion after 3 chars
            if partial_name.length >= 3
              # Get available models (with caching)
              models = get_available_models(debug_enabled)
              
              # Find matching models
              matches = models.select { |model| model.start_with?(partial_name) }
              puts "Found #{matches.size} matches: #{matches.inspect}" if debug_enabled
              
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
          puts "Error in completion handler: #{e.message}" if debug_enabled
          puts e.backtrace.join("\n") if debug_enabled
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

      if input.start_with?('/')
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
                            puts "Error: Unknown mode type '#{mode_type}'"
                            return # Don't switch if mode is unknown
                          end

      @current_mode = new_mode_instance
      # Use the new mode's prompt to get the name implicitly
      mode_name = @current_mode.class.name.split('::').last.gsub('Mode', '')
      puts "Switched to #{mode_name} mode."
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
                        puts "Error: Cannot run in unknown mode type '#{mode_type}'"
                        return
                      end
      mode_instance.handle_input(input)
    rescue StandardError => e # Catch errors during temporary execution
        puts "[Unexpected Error during one-off execution in #{mode_type} mode] #{e.class}: #{e.message}"
        puts e.backtrace.join("\n") if ENV['DEBUG']
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
