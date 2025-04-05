# Repl Class Refactoring Plan

## Current State Analysis

After reviewing the codebase, I've identified that the `Repl` class has already undergone significant refactoring to extract mode-specific behavior into dedicated classes and move command handling to a separate class. However, there are still several opportunities to improve testability and separation of concerns.

## Key Issues

1. **Dependency Creation vs. Injection**
   - The `Repl` class directly instantiates its dependencies
   - This makes it difficult to substitute mock objects for testing
   - Dependencies are tightly coupled to specific implementations

2. **Mode Management Duplication**
   - Similar mode creation logic appears in both `switch_mode` and `run_in_mode` methods
   - Adding a new mode requires changes in multiple places
   - Mode creation logic is tightly coupled to specific mode implementations

3. **Readline Integration**
   - Complex `setup_readline` method with nested conditional logic
   - Direct coupling to the Readline library makes testing difficult
   - Model completion logic is mixed with UI concerns

4. **Model Caching**
   - Caching logic embedded directly in the `Repl` class
   - Intermixes time-based cache management with model retrieval
   - Not easily testable in isolation

5. **Input/Output Handling**
   - Direct use of `puts` and `readline` throughout the class
   - Mixes business logic with terminal I/O, complicating testing
   - No abstraction for input/output operations

6. **Run Loop Complexity**
   - The `run` method contains a large, complex loop handling multiple concerns
   - Error handling, command processing, and flow control are intermingled
   - Difficult to test without running the entire loop

## Proposed Refactorings

### 1. Extract Mode Factory

Create a dedicated `ModeFactory` class to handle mode creation:

```ruby
module OllamaRepl
  class ModeFactory
    def initialize(client, context_manager)
      @client = client
      @context_manager = context_manager
    end
    
    def create(mode_type)
      case mode_type
      when :llm
        Modes::LlmMode.new(@client, @context_manager)
      when :ruby
        Modes::RubyMode.new(@client, @context_manager)
      when :shell
        Modes::ShellMode.new(@client, @context_manager)
      else
        raise ArgumentError, "Unknown mode type '#{mode_type}'"
      end
    end
  end
end
```

Benefits:
- Centralizes mode creation logic in one place
- Adding a new mode requires changes to only one class
- Makes `Repl` more testable by allowing mode factory mocking

### 2. Create I/O Service

Extract terminal I/O into a dedicated service:

```ruby
module OllamaRepl
  class IOService
    def display(message)
      puts message
    end
    
    def prompt(prompt_text)
      Readline.readline(prompt_text, true)
    end
    
    def display_error(message)
      puts "[Error] #{message}"
    end
  end
end
```

Benefits:
- Abstracts I/O operations behind an interface
- Facilitates testing by allowing I/O mocking
- Centralizes output formatting

### 3. Extract Model Cache Service

Create a dedicated service for model caching:

```ruby
module OllamaRepl
  class ModelCacheService
    CACHE_DURATION = 300 # 5 minutes in seconds
    
    def initialize(client)
      @client = client
      @available_models_cache = nil
      @last_cache_time = nil
    end
    
    def get_models(debug_enabled = false)
      current_time = Time.now
      
      if @available_models_cache.nil? || @last_cache_time.nil? ||
         (current_time - @last_cache_time) > CACHE_DURATION
        refresh_cache(debug_enabled)
      else
        puts "Using cached models (#{@available_models_cache.size})" if debug_enabled
      end
      
      @available_models_cache
    end
    
    private
    
    def refresh_cache(debug_enabled)
      puts "Refreshing models cache" if debug_enabled
      begin
        @available_models_cache = @client.list_models.sort
        @last_cache_time = Time.now
        puts "Cache updated with #{@available_models_cache.size} models" if debug_enabled
      rescue => e
        puts "Error fetching models: #{e.message}" if debug_enabled
        @available_models_cache ||= []
      end
    end
  end
end
```

Benefits:
- Encapsulates caching logic in a dedicated class
- Easier to test cache behavior in isolation
- Single responsibility principle applied

### 4. Create Readline Service

Extract Readline configuration and interaction:

```ruby
module OllamaRepl
  class ReadlineService
    def initialize(model_cache_service)
      @model_cache_service = model_cache_service
    end
    
    def setup
      Readline.completion_proc = method(:completion_handler)
      Readline.completion_append_character = " "
    end
    
    def read_input(prompt)
      Readline.readline(prompt, true)
    end
    
    private
    
    def completion_handler(input)
      debug_enabled = ENV['DEBUG'] == 'true'
      
      begin
        line = Readline.line_buffer
        
        if line.start_with?('/model ')
          handle_model_completion(line, debug_enabled)
        else
          []
        end
      rescue => e
        puts "Error in completion handler: #{e.message}" if debug_enabled
        puts e.backtrace.join("\n") if debug_enabled
        []
      end
    end
    
    def handle_model_completion(line, debug_enabled)
      partial_name = line[7..-1] || ""
      
      puts "Model completion: line='#{line}', partial='#{partial_name}'" if debug_enabled
      
      if partial_name.length >= 3
        models = @model_cache_service.get_models(debug_enabled)
        
        matches = models.select { |model| model.start_with?(partial_name) }
        puts "Found #{matches.size} matches: #{matches.inspect}" if debug_enabled
        
        matches.empty? ? [] : matches
      else
        []
      end
    end
  end
end
```

Benefits:
- Encapsulates Readline configuration logic
- Separates input handling from business logic
- Makes testing input handling easier

### 5. Improve Dependency Injection in Repl

Refactor `Repl` to accept dependencies through constructor:

```ruby
module OllamaRepl
  class Repl
    attr_reader :client, :context_manager
    
    def initialize(dependencies = {})
      @client = dependencies[:client] || build_client
      @context_manager = dependencies[:context_manager] || ContextManager.new
      @io_service = dependencies[:io_service] || IOService.new
      @model_cache_service = dependencies[:model_cache_service] || ModelCacheService.new(@client)
      @mode_factory = dependencies[:mode_factory] || ModeFactory.new(@client, @context_manager)
      @readline_service = dependencies[:readline_service] || ReadlineService.new(@model_cache_service)
      
      # Initialize the starting mode object
      @current_mode = dependencies[:initial_mode] || @mode_factory.create(:llm)
      
      # Initialize command handler
      @command_handler = dependencies[:command_handler] || 
                         CommandHandler.new(self, @context_manager)
      
      @readline_service.setup
    rescue Error => e # Catch configuration or initial connection errors
      @io_service.display_error(e.message)
      exit 1
    end
    
    # ... rest of the class
    
    private
    
    def build_client
      Config.validate_config!
      Client.new(Config.ollama_host, Config.ollama_model)
    end
  end
end
```

Benefits:
- Allows injection of mock objects for testing
- Makes dependencies explicit
- Provides defaults for backward compatibility

### 6. Simplify Run Method

Break down the complex `run` method into smaller, focused methods:

```ruby
def run
  display_welcome_message
  check_initial_connection
  
  main_loop
rescue Error => e
  @io_service.display_error(e.message)
  @io_service.display("Please check your OLLAMA_HOST and OLLAMA_MODEL settings and ensure Ollama is running.")
  exit 1
end

private

def display_welcome_message
  @io_service.display("Welcome to Ollama REPL!")
  @io_service.display("Using model: #{@client.current_model}")
  @io_service.display("Type `/help` for commands.")
end

def check_initial_connection
  begin
    @client.check_connection_and_model
  rescue Client::ModelNotFoundError => e
    handle_model_not_found_error(e)
  end
end

def handle_model_not_found_error(error)
  @io_service.display_error(error.message)
  @io_service.display("Available models: #{error.available_models.join(', ')}")
  @io_service.display("Please select an available model using the command: /model {model_name}")
end

def main_loop
  loop do
    begin
      handle_input_iteration
    rescue Interrupt
      @io_service.display("\nType /exit or /quit to leave.")
    rescue Client::ApiError => e
      @io_service.display_error("API Error: #{e.message}")
    rescue StandardError => e
      handle_unexpected_error(e)
    end
  end
end

def handle_input_iteration
  prompt = current_prompt
  input = @readline_service.read_input(prompt)
  
  if input.nil?
    @io_service.display("\nExiting.")
    return :exit # Signal to exit the loop
  end
  
  input.strip!
  
  # Add non-empty input to history
  Readline::HISTORY.push(input) unless input.empty?
  
  # Exit commands
  return :exit if ['/exit', '/quit'].include?(input.downcase)
  
  process_input(input)
  return :continue # Signal to continue the loop
end

def handle_unexpected_error(error)
  @io_service.display_error("Unexpected Error: #{error.class}: #{error.message}")
  @io_service.display(error.backtrace.join("\n")) if ENV['DEBUG']
end
```

Benefits:
- Each method has a single responsibility
- Improved readability and maintainability
- Easier to test individual components

### 7. Simplify Mode Handling

Use the `ModeFactory` to simplify the `switch_mode` and `run_in_mode` methods:

```ruby
def switch_mode(mode_type)
  begin
    new_mode_instance = @mode_factory.create(mode_type)
    @current_mode = new_mode_instance
    
    mode_name = @current_mode.class.name.split('::').last.gsub('Mode', '')
    @io_service.display("Switched to #{mode_name} mode.")
  rescue ArgumentError => e
    @io_service.display_error(e.message)
  end
end

def run_in_mode(mode_type, input)
  begin
    mode_instance = @mode_factory.create(mode_type)
    mode_instance.handle_input(input)
  rescue ArgumentError => e
    @io_service.display_error(e.message)
  rescue StandardError => e
    @io_service.display_error("Unexpected Error during one-off execution in #{mode_type} mode: #{e.class}: #{e.message}")
    @io_service.display(e.backtrace.join("\n")) if ENV['DEBUG']
  end
end
```

Benefits:
- Eliminates duplicated mode creation logic
- Uses the factory to handle mode creation
- Better error handling

## Implementation Strategy

1. Create the new service classes first (ModeFactory, IOService, ModelCacheService, ReadlineService)
2. Update the Repl constructor to support dependency injection
3. Refactor the run method to use the new services
4. Update switch_mode and run_in_mode to use the ModeFactory
5. Update tests to leverage the new testable structure

## Testing Improvements

With these changes, testing will be significantly improved:

1. We can mock all dependencies to test Repl in isolation
2. Individual services can be tested independently
3. We can simulate different scenarios by configuring mock dependencies
4. The smaller, focused methods are easier to test individually

## Future Considerations

1. **Command Registration System**: Implement a more dynamic system for registering commands in the CommandHandler
2. **Plugin Architecture**: Consider a plugin system for extending functionality without modifying core classes
3. **Configuration Improvements**: Extract more configuration options to make the application more customizable
4. **Event System**: Implement an event system for communication between components instead of direct references

This refactoring plan focuses on making the code more testable with proper separation of concerns, while maintaining backward compatibility.