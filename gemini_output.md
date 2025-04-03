```ruby
# ollama_repl.gemspec

require_relative "lib/ollama_repl/version"

Gem::Specification.new do |spec|
  spec.name          = "ollama_repl"
  spec.version       = OllamaRepl::VERSION
  spec.authors       = ["Your Name"] # Placeholder
  spec.email         = ["your.email@example.com"] # Placeholder

  spec.summary       = "A terminal REPL chat interface for Ollama."
  spec.description   = "Provides a Read-Eval-Print Loop (REPL) in the terminal to interact with an Ollama API, maintaining conversation history and allowing execution of local Ruby code."
  spec.homepage      = "https://github.com/yourusername/ollama_repl" # Placeholder
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'" # Placeholder

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here." # Placeholder

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Executable file
  spec.executables << 'ollama-repl'

  # Runtime dependencies
  spec.add_dependency "dotenv", "~> 2.8"
  spec.add_dependency "faraday", "~> 2.7"
  spec.add_dependency "faraday-net_http", "~> 3.0" # Explicit adapter
  spec.add_dependency "readline", "~> 0"          # Included with Ruby, but good practice

  # Development dependencies (optional)
  # spec.add_development_dependency "bundler", "~> 2.3"
  # spec.add_development_dependency "rake", "~> 13.0"
  # spec.add_development_dependency "rspec", "~> 3.0"
end
```

```ruby
# lib/ollama_repl/version.rb

module OllamaRepl
  VERSION = "0.1.0"
end
```

```ruby
# lib/ollama_repl/config.rb

require 'dotenv/load' # Load .env file if present

module OllamaRepl
  module Config
    def self.ollama_host
      # Ensure no trailing slash and handle potential nil
      (ENV['OLLAMA_HOST'] || 'http://localhost:11434').chomp('/')
    end

    def self.ollama_model
      ENV['OLLAMA_MODEL']
    end

    def self.validate_config!
      if ollama_model.nil? || ollama_model.empty?
        raise Error, "Configuration error: OLLAMA_MODEL environment variable must be set."
      end
      # Basic URL check (not exhaustive)
      unless ollama_host =~ /\Ahttps?:\/\//
         raise Error, "Configuration error: OLLAMA_HOST must be a valid URL (e.g., http://localhost:11434)."
      end
    end
  end
end
```

```ruby
# lib/ollama_repl/client.rb

require 'faraday'
require 'faraday/net_http' # Explicitly require adapter
require 'json'
require 'uri'

module OllamaRepl
  class Client
    class ApiError < StandardError; end

    def initialize(host, model)
      @host = host
      @model = model
      @conn = Faraday.new(url: @host) do |faraday|
        faraday.adapter Faraday::Adapter::NetHttp # Use Net::HTTP adapter
        faraday.request :json # Send request body as JSON
        faraday.response :json, content_type: /\bjson$/ # Parse JSON response bodies
        faraday.response :raise_error # Raise errors on 4xx/5xx responses
      end
    end

    def current_model
      @model
    end

    def update_model(new_model)
      @model = new_model
    end

    def chat(messages)
      payload = {
        model: @model,
        messages: messages,
        stream: false # Keep it simple for now
      }
      puts "[Debug] Sending to Ollama: #{payload.inspect}" if ENV['DEBUG']
      response = @conn.post('/api/chat', payload)
      puts "[Debug] Received from Ollama: #{response.body.inspect}" if ENV['DEBUG']
      response.body['message']['content'] # Extract content
    rescue Faraday::Error => e
      raise ApiError, "API request failed: #{e.message} (Response: #{e.response_body if e.respond_to?(:response_body)})"
    rescue JSON::ParserError => e
      raise ApiError, "Failed to parse API response: #{e.message}"
    rescue NoMethodError, TypeError => e
      # Handle cases where response structure is unexpected
      raise ApiError, "Unexpected API response structure: #{e.message} (Body: #{response&.body || 'N/A'})"
    end

    def list_models
      response = @conn.get('/api/tags')
      response.body['models'].map { |m| m['name'] } # Extract model names
    rescue Faraday::Error => e
      raise ApiError, "API request failed to list models: #{e.message} (Response: #{e.response_body if e.respond_to?(:response_body)})"
    rescue JSON::ParserError => e
      raise ApiError, "Failed to parse models API response: #{e.message}"
    rescue NoMethodError, TypeError => e
      raise ApiError, "Unexpected models API response structure: #{e.message} (Body: #{response&.body || 'N/A'})"
    end

    # Check if the API host is reachable and the model exists
    def check_connection_and_model
      # 1. Check connection by listing models (lightweight)
      list_models
      # 2. Check if the specific model exists
      unless list_models.include?(@model)
        raise Error, "Error: Configured model '#{@model}' not found on Ollama host '#{@host}'. Available models: #{list_models.join(', ')}"
      end
      true
    rescue ApiError => e
      raise Error, "Error connecting to Ollama at #{@host}: #{e.message}"
    end
  end
end
```

```ruby
# lib/ollama_repl/repl.rb

require 'readline'
require 'stringio'
require 'pathname'
require_relative 'config'
require_relative 'client'

module OllamaRepl
  class Repl
    MODE_LLM = :llm
    MODE_RUBY = :ruby

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
      @messages = [] # Conversation history
      @mode = MODE_LLM
      setup_readline
    rescue Error => e # Catch configuration or initial connection errors
      puts "[Error] #{e.message}"
      exit 1
    end

    def run
      puts "Welcome to Ollama REPL!"
      puts "Using model: #{@client.current_model}"
      puts "Type `/help` for commands."

      # Check initial connection and model validity
      begin
        @client.check_connection_and_model
      rescue Error => e
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

    private

    def setup_readline
      # Potential future Readline configuration (e.g., autocompletion)
    end

    def current_prompt
      case @mode
      when MODE_LLM
        "🤖 > "
      when MODE_RUBY
        "💎 > "
      else
        "> "
      end
    end

    def process_input(input)
      return if input.empty?

      if input.start_with?('/')
        handle_command(input)
      else
        case @mode
        when MODE_LLM
          handle_llm_input(input)
        when MODE_RUBY
          handle_ruby_input(input)
        end
      end
    end

    def handle_command(input)
      parts = input.split(' ', 2)
      command = parts[0].downcase
      args = parts[1]

      case command
      when '/llm'
        if args && !args.empty?
          handle_llm_input(args) # Single LLM prompt
        else
          switch_mode(MODE_LLM) # Switch durable mode
        end
      when '/ruby'
        if args && !args.empty?
          handle_ruby_input(args) # Single Ruby execution
        else
          switch_mode(MODE_RUBY) # Switch durable mode
        end
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
         # Handled in main loop, but included here for completeness
         puts "Exiting."
         exit 0
      else
        puts "Unknown command: #{command}. Type /help for available commands."
      end
    end

    def switch_mode(new_mode)
      @mode = new_mode
      mode_name = new_mode == MODE_LLM ? "LLM" : "Ruby"
      puts "Switched to #{mode_name} mode."
    end

    def add_message(role, content)
      @messages << { role: role, content: content }
    end

    def handle_llm_input(prompt)
      puts "🤖 Thinking..."
      add_message('user', prompt)
      begin
        response_content = @client.chat(@messages)
        puts "\nAssistant:"
        puts response_content
        puts "" # Add a newline for spacing
        add_message('assistant', response_content)
      rescue Client::ApiError => e
        puts "[API Error interacting with LLM] #{e.message}"
        # Optionally remove the user message that failed
        # @messages.pop if @messages.last&.dig(:role) == 'user'
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
        lang = FILE_TYPE_MAP[extension] || '' # Get lang identifier or empty string

        formatted_content = "System Message: File Content (#{File.basename(file_path)})\n"
        formatted_content += "```#{lang}\n"
        formatted_content += content
        formatted_content += "\n```"

        add_message('system', formatted_content)
        puts "Added content from #{File.basename(file_path)} to context."

      rescue StandardError => e
        puts "Error reading file #{file_path}: #{e.message}"
      end
    end

    def handle_model_command(args)
      available_models = @client.list_models # Fetch fresh list

      if args.nil? || args.empty?
        # List models
        if available_models.empty?
            puts "No models available on the Ollama host."
        else
            puts "Available models:"
            available_models.each { |m| puts "- #{m}" }
            puts "\nCurrent model: #{@client.current_model}"
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
        @client.update_model(chosen_model)
        puts "Model set to '#{chosen_model}'."
        # Optionally, clear context when changing model? Or inform user context is kept.
        # puts "Conversation context remains."
      end

    rescue Client::ApiError => e
       puts "[API Error managing models] #{e.message}"
    end

    def display_context
      puts "\n--- Conversation Context ---"
      if @messages.empty?
        puts "(empty)"
      else
        @messages.each_with_index do |msg, index|
          puts "[#{index + 1}] #{msg[:role].capitalize}:"
          puts msg[:content]
          puts "---"
        end
      end
      puts "Total messages: #{@messages.length}"
      puts "--------------------------\n"
    end

    def clear_context
      print "Are you sure you want to clear the conversation history? (y/N): "
      confirmation = $stdin.gets.chomp.downcase # Use $stdin here, not Readline
      if confirmation == 'y'
        @messages = []
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
      puts
      puts "One-off Actions (stay in current durable mode):"
      puts "  /llm {prompt}  Send a single prompt to the LLM."
      puts "  /ruby {code}   Execute a single line of Ruby code."
      puts
      puts "Commands:"
      puts "  /file {path}   Add the content of the specified file to the context."
      puts "  /model         List available Ollama models."
      puts "  /model {name}  Switch to the specified Ollama model (allows prefix matching)."
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

```

```ruby
# lib/ollama_repl.rb

# Stdlib requires
require 'pathname'
require 'readline'
require 'json'
require 'stringio'
require 'uri'

# Gem requires
require 'dotenv/load'
require 'faraday'
require 'faraday/net_http'

# Internal requires
require_relative "ollama_repl/version"
require_relative "ollama_repl/config"
require_relative "ollama_repl/client"
require_relative "ollama_repl/repl"

module OllamaRepl
  class Error < StandardError; end

  def self.run
    Repl.new.run
  end
end
```

```ruby
#!/usr/bin/env ruby

# bin/ollama-repl

# Set up load paths for development testing without installing the gem
# This assumes the script is run from the project root or the gem is installed.
begin
  # Try loading the installed gem first
  require 'ollama_repl'
rescue LoadError
  # If gem not installed, assume running from source directory
  lib_path = File.expand_path('../lib', __dir__)
  $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
  begin
    require 'ollama_repl'
  rescue LoadError => e
    puts "Error: Could not load the OllamaRepl library."
    puts "Please ensure the gem is installed (`gem install ollama_repl`)"
    puts "or run this script from the root of the gem's source directory."
    puts "Original error: #{e.message}"
    exit 1
  end
end

# Start the REPL
OllamaRepl.run
```

```ruby
# .env (Example file - Do not include in the final output, but for user's reference)
#
# Ollama API Configuration
#
# OLLAMA_HOST=http://localhost:11434
# OLLAMA_MODEL=llama3 # Replace with your desired default model
#
# Optional: Enable Debug logging for Faraday requests
# DEBUG=true
```
