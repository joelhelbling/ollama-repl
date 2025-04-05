# frozen_string_literal: true
require 'open3'
require 'readline'
require 'stringio'
require 'pathname'
require_relative 'config'
require_relative 'client'
require_relative 'command_handler'
require_relative 'context_manager'

module OllamaRepl
  class Repl
    # Make client and context_manager accessible to the CommandHandler
    attr_reader :client, :context_manager
    MODE_LLM = :llm
    MODE_RUBY = :ruby
    MODE_SHELL = :shell

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
      @mode = MODE_LLM
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

    def current_prompt
      case @mode
      when MODE_LLM
        "🤖 ❯ "
      when MODE_RUBY
        "💎 ❯ "
      when MODE_SHELL
        "🐚 ❯ "
      else
        "?! ❯ "
      end
    end

    def process_input(input)
      return if input.empty?

      if input.start_with?('/')
        @command_handler.handle(input) # Delegate to the command handler
      else
        case @mode
        when MODE_LLM
          handle_llm_input(input)
        when MODE_RUBY
          handle_ruby_input(input)
        when MODE_SHELL
          handle_shell_input(input)
        end
      end
    end

    # The command handling methods have been moved to CommandHandler
    # Keeping switch_mode and other support methods needed by CommandHandler

    def switch_mode(new_mode)
      @mode = new_mode
      mode_name = case new_mode
                  when MODE_LLM
                    "LLM"
                  when MODE_RUBY
                    "Ruby"
                  when MODE_SHELL
                    "Shell"
                  else
                    "Unknown"
                  end
      puts "Switched to #{mode_name} mode."
    end

    def add_message(role, content)
      @context_manager.add(role, content)
    end

    def handle_llm_input(prompt)
      add_message('user', prompt)
      full_response = String.new # Use String.new to ensure mutability
      print "\nAssistant: " # Print prefix once

      begin
        @client.chat(@context_manager.for_api) do |chunk|
          # Extract content from the message part of the chunk
          content_part = chunk.dig('message', 'content')
          unless content_part.nil? || content_part.empty?
            print content_part # Stream output directly to the console
            $stdout.flush # Ensure it appears immediately
            full_response << content_part
          end

          # Check if the stream is done (Ollama specific field)
          # if chunk['done']
          #   # Optional: Handle end-of-stream logic if needed,
          #   # like printing final stats if provided in the chunk.
          # end
        end
        puts "" # Add a final newline after streaming is complete

        # Add the complete response to history *after* streaming finishes
        add_message('assistant', full_response) unless full_response.empty?

      rescue Client::ApiError => e
        puts "\n[API Error interacting with LLM] #{e.message}"
        # Optionally remove the user message that failed
        # @messages.pop if @messages.last&.dig(:role) == 'user'
      ensure
        # Ensure a newline even if there was an error during streaming
        puts "" unless full_response.empty?
      end
    end

    def handle_ruby_input(code)
      puts "💎 Executing..."
      add_message('user', "Execute Ruby code: ```ruby\n#{code}\n```") # Add code to context first

      stdout_str, stderr_str, error = capture_ruby_execution(code)

      output_message = "System Message: Ruby Execution Output\n"
      output_message += "STDOUT:\n"
      output_message += stdout_str.empty? ? "(empty)\n" : stdout_str
      output_message += "STDERR:\n"
      output_message += stderr_str.empty? ? "(empty)\n" : stderr_str

      if error
        error_details = "Error: #{error.class}: #{error.message}\nBacktrace:\n#{error.backtrace.join("\n")}"
        output_message += "Exception:\n#{error_details}"
        puts "[Ruby Execution Error]"
        puts error_details
      else
        puts "[Ruby Execution Result]"
      end

      puts "--- STDOUT ---"
      puts stdout_str.empty? ? "(empty)" : stdout_str
      puts "--- STDERR ---"
      puts stderr_str.empty? ? "(empty)" : stderr_str
      puts "--------------"

      add_message('system', output_message)
    end

    def capture_ruby_execution(code)
      original_stdout = $stdout
      original_stderr = $stderr
      stdout_capture = StringIO.new
      stderr_capture = StringIO.new
      $stdout = stdout_capture
      $stderr = stderr_capture
      error = nil

      begin
        # Using Kernel#eval directly. Be cautious.
        eval(code, binding) # Use current binding or create a clean one if needed
      rescue Exception => e # Catch StandardError and descendants
        error = e
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end

      [stdout_capture.string, stderr_capture.string, error]
    end

    # The following methods have been moved to CommandHandler:
    # - handle_file_command
    # - handle_model_command
    # - display_context
    # - clear_context
    # - display_help
    
    def handle_shell_input(command)
      puts "❯ Executing..."
      add_message('user', "Execute shell command: ```\n#{command}\n```") # Add code to context first

      stdout_str, stderr_str, error = capture_shell_execution(command)

      output_message = "System Message: Shell Execution Output\n"
      output_message += "STDOUT:\n"
      output_message += stdout_str.empty? ? "(empty)\n" : stdout_str
      output_message += "STDERR:\n"
      output_message += stderr_str.empty? ? "(empty)\n" : stderr_str

      if error
        error_details = "Error: #{error.class}: #{error.message}\nBacktrace:\n#{error.backtrace.join("\n")}"
        output_message += "Exception:\n#{error_details}"
        puts "[Shell Execution Error]"
        puts error_details
      else
        puts "[Shell Execution Result]"
      end

      puts "--- STDOUT ---"
      puts stdout_str.empty? ? "(empty)" : stdout_str
      puts "--- STDERR ---"
      puts stderr_str.empty? ? "(empty)" : stderr_str
      puts "--------------"
      add_message('system', output_message)
    end

    private

    def capture_shell_execution(command)
      stdout_str = ""
      stderr_str = ""
      error = nil

      begin
        # Execute the command and capture stdout and stderr
        stdout_str, stderr_str, status = Open3.capture3(command)
        if !status.success?
          stderr_str += "Command exited with status: #{status.exitstatus}"
        end
      rescue StandardError => e
        error = e
      end

      [stdout_str, stderr_str, error]
    end
  end
end
