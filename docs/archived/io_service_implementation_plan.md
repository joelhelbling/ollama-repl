# IO Service Implementation Plan

## Overview

The IO Service refactoring will extract all console input/output operations from the Repl class and other parts of the application into a dedicated service class. This will improve testability, create a consistent interface for terminal interactions, and better separate concerns.

## Implementation Steps

### 1. Create IOService Class

Create a new file `lib/ollama_repl/io_service.rb` with the following content:

```ruby
# frozen_string_literal: true

require 'readline'

module OllamaRepl
  # Service class for handling all input/output operations
  # This provides a consistent interface for terminal interactions
  # and improves testability by allowing I/O mocking
  class IOService
    # Display a message to the user
    # @param message [String] The message to display
    def display(message)
      puts message
    end
    
    # Display an error message with standard formatting
    # @param message [String] The error message
    def display_error(message)
      puts "[Error] #{message}"
    end
    
    # Display an API error message
    # @param message [String] The API error message
    def display_api_error(message)
      puts "[API Error] #{message}"
    end
    
    # Display a detailed execution error with optional stack trace
    # @param context [String] The execution context (e.g., "ruby", "shell")
    # @param error [Exception] The error object
    def display_execution_error(context, error)
      puts "[Unexpected Error during #{context} execution] #{error.class}: #{error.message}"
      puts error.backtrace.join("\n") if ENV['DEBUG']
    end
    
    # Prompt the user for input
    # @param prompt_text [String] The prompt text to display
    # @param add_to_history [Boolean] Whether to add the input to Readline history
    # @return [String, nil] The user's input, or nil if end-of-file
    def prompt(prompt_text, add_to_history = true)
      Readline.readline(prompt_text, add_to_history)
    end
    
    # Display a debug message if debugging is enabled
    # @param message [String] The debug message
    # @param debug_enabled [Boolean] Whether debugging is enabled
    def debug(message, debug_enabled = false)
      puts message if debug_enabled
    end
    
    # Exit the application with an error message
    # @param message [String] The error message to display before exiting
    # @param exit_code [Integer] The exit code (defaults to 1)
    def exit_with_error(message, exit_code = 1)
      display_error(message)
      exit exit_code
    end
  end
end
```

### 2. Create IOService Tests

Create a new file `spec/ollama_repl/io_service_spec.rb` with the following content:

```ruby
# frozen_string_literal: true

RSpec.describe OllamaRepl::IOService do
  let(:io_service) { described_class.new }

  describe "#display" do
    it "outputs the message to stdout" do
      expect { io_service.display("Test message") }.to output("Test message\n").to_stdout
    end
  end

  describe "#display_error" do
    it "outputs a formatted error message" do
      expect { io_service.display_error("Something went wrong") }.to output("[Error] Something went wrong\n").to_stdout
    end
  end
  
  describe "#display_api_error" do
    it "outputs a formatted API error message" do
      expect { io_service.display_api_error("API connection failed") }.to output("[API Error] API connection failed\n").to_stdout
    end
  end
  
  describe "#display_execution_error" do
    it "outputs detailed error information" do
      error = StandardError.new("Test error")
      allow(error).to receive(:backtrace).and_return(["line 1", "line 2"])
      
      # Without debug
      without_debug = "[Unexpected Error during ruby execution] StandardError: Test error\n"
      expect { io_service.display_execution_error("ruby", error) }.to output(without_debug).to_stdout
      
      # With debug
      allow(ENV).to receive(:[]).with('DEBUG').and_return('true')
      with_debug = "[Unexpected Error during ruby execution] StandardError: Test error\nline 1\nline 2\n"
      expect { io_service.display_execution_error("ruby", error) }.to output(with_debug).to_stdout
    end
  end

  describe "#prompt" do
    it "uses Readline to get user input" do
      allow(Readline).to receive(:readline).with("Test prompt: ", true).and_return("user input")
      expect(io_service.prompt("Test prompt: ")).to eq("user input")
    end
    
    it "respects the add_to_history parameter" do
      allow(Readline).to receive(:readline).with("Test prompt: ", false).and_return("user input")
      expect(io_service.prompt("Test prompt: ", false)).to eq("user input")
    end
  end

  describe "#debug" do
    it "outputs debug messages when debug_enabled is true" do
      expect { io_service.debug("Debug message", true) }.to output("Debug message\n").to_stdout
    end

    it "doesn't output debug messages when debug_enabled is false" do
      expect { io_service.debug("Debug message", false) }.not_to output.to_stdout
    end
  end
  
  describe "#exit_with_error" do
    it "displays an error message and exits with the specified code" do
      expect(io_service).to receive(:display_error).with("Critical error")
      expect(io_service).to receive(:exit).with(2)
      
      io_service.exit_with_error("Critical error", 2)
    end
    
    it "uses exit code 1 by default" do
      expect(io_service).to receive(:display_error).with("Critical error")
      expect(io_service).to receive(:exit).with(1)
      
      io_service.exit_with_error("Critical error")
    end
  end
end
```

### 3. Update Repl Class

Update `lib/ollama_repl/repl.rb` to use the IOService:

1. Add the require statement:
```ruby
require_relative 'io_service'
```

2. Update the constructor to support dependency injection:
```ruby
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
```

3. Update the run method:
```ruby
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
    break if ['/exit', '/quit'].include?(input.downcase)
    
    process_input(input)
    
  rescue Interrupt # Handle Ctrl+C
    @io_service.display("\nType /exit or /quit to leave.")
  rescue Client::ApiError => e
    @io_service.display_api_error(e.message)
  rescue StandardError => e
    @io_service.display_execution_error("general", e)
  end
end
```

4. Add a helper method for model not found errors:
```ruby
def handle_model_not_found_error(error)
  @io_service.display_error(error.message)
  @io_service.display("Available models: #{error.available_models.join(', ')}")
  @io_service.display("Please select an available model using the command: /model {model_name}")
end
```

5. Update the switch_mode method:
```ruby
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
  mode_name = @current_mode.class.name.split('::').last.gsub('Mode', '')
  @io_service.display("Switched to #{mode_name} mode.")
end
```

6. Update the run_in_mode method:
```ruby
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
rescue StandardError => e # Catch errors during temporary execution
  @io_service.display_execution_error(mode_type.to_s, e)
end
```

7. Update the setup_readline method - replace debug output with io_service:
```ruby
def setup_readline
  # No longer need to initialize model cache variables here
  
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
```

### 4. Update CommandHandler Class

Update `lib/ollama_repl/command_handler.rb` to use the IOService:

1. Update the constructor:
```ruby
def initialize(repl, context_manager, io_service)
  @repl = repl
  @context_manager = context_manager
  @io_service = io_service
end
```

2. Replace all puts/print calls with IOService methods.
   For example:
```ruby
puts "Unknown command: #{command}. Type /help for available commands."
```
becomes:
```ruby
@io_service.display("Unknown command: #{command}. Type /help for available commands.")
```

3. Handle user confirmation:
```ruby
def clear_context
  @io_service.display("Are you sure you want to clear the conversation history? (y/N): ")
  confirmation = $stdin.gets.chomp.downcase # Direct stdin usage needed here
  if confirmation == 'y'
    @context_manager.clear
    @io_service.display("Conversation context cleared.")
  else
    @io_service.display("Clear context cancelled.")
  end
end
```

### 5. Update Tests

1. Update `spec/ollama_repl/repl_spec.rb` to mock the IOService:

```ruby
before(:each) do
  # Existing setup...
  
  # Mock IOService
  @io_service = instance_double("OllamaRepl::IOService")
  allow(OllamaRepl::IOService).to receive(:new).and_return(@io_service)
  allow(@io_service).to receive(:display)
  allow(@io_service).to receive(:display_error)
  allow(@io_service).to receive(:display_api_error)
  allow(@io_service).to receive(:display_execution_error)
  allow(@io_service).to receive(:prompt).and_return("test input", nil)
  allow(@io_service).to receive(:debug)
  allow(@io_service).to receive(:exit_with_error)
end
```

2. Update `spec/ollama_repl/command_handler_spec.rb` to pass the IOService:

```ruby
let(:io_service) { instance_double("OllamaRepl::IOService") }
let(:command_handler) { OllamaRepl::CommandHandler.new(repl, context_manager, io_service) }

before(:each) do
  # Allow io_service methods that will be called
  allow(io_service).to receive(:display)
  allow(io_service).to receive(:display_error)
end
```

## Error Handling Integration

The IOService enhances error handling by:

1. Providing consistent error formatting across the application
2. Categorizing errors with different prefixes (Error, API Error, Unexpected Error)
3. Handling debug output in a centralized way
4. Providing a clean method for error-based application exit

## Benefits

1. **Improved Testability**: All I/O operations can now be mocked, making tests more reliable
2. **Separation of Concerns**: Business logic is separated from I/O concerns
3. **Consistent Error Handling**: All error messages have a consistent format
4. **Centralized Debug Output**: Debug messages are handled consistently
5. **Dependency Injection**: Components can be more easily replaced for testing