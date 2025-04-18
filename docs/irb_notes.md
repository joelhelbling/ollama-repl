# IRB Integration Notes

This document outlines considerations and implementation details for integrating IRB with the OllamaRepl gem, particularly for addressing persistent state in Ruby mode and enabling Rails console integration.

## Current Limitations

The current RubyMode implementation executes each command in a separate Ruby process, which means:
- Variables defined in one command are not available in the next
- Methods and classes defined in one command cannot be used in subsequent commands
- No persistence of any Ruby state between commands

## IRB Integration Approach

### Benefits

1. **Persistent State**: IRB naturally maintains state between commands
2. **Feature-Rich**: Access to IRB's built-in features (history, tab completion, etc.)
3. **Rails Integration**: Rails console is built on IRB, enabling direct integration
4. **Developer Familiarity**: Most Ruby developers already know IRB's interface
5. **Ecosystem**: Access to IRB plugins and extensions

### Implementation Considerations

#### 1. IRB Input/Output Integration

- Create custom implementations of `IRB::InputMethod` and `IRB::OutputMethod`
- Capture all IRB output as system messages in the context manager
- Format Ruby input as user messages in the context manager
- Ensure proper display to the user

```ruby
class ContextCapturingInputMethod < IRB::InputMethod
  def initialize(context_manager, io_service)
    @context_manager = context_manager
    @io_service = io_service
    super("context_capturing")
  end
  
  def gets
    input = @io_service.prompt("💎 ❯ ")
    @context_manager.add("user", "```ruby\n#{input}\n```") unless input.nil?
    input
  end
end

class ContextCapturingOutputMethod < IRB::OutputMethod
  def initialize(context_manager, io_service)
    @context_manager = context_manager
    @io_service = io_service
    @output_buffer = StringIO.new
  end
  
  def puts(*objs)
    objs.each do |obj|
      @io_service.display(obj.to_s)
      @output_buffer.puts(obj)
    end
  end
  
  def flush
    output = @output_buffer.string
    @context_manager.add("system", "Ruby Output:\n```\n#{output}\n```")
    @output_buffer = StringIO.new
  end
end
```

#### 2. State Management

- Initialize IRB once per session and maintain it
- Create a workspace with appropriate binding
- Handle proper cleanup when switching modes
- Implement reset capability if needed

#### 3. Command Integration

- Create an `IrbCommand` class similar to `RubyCommand`
- Handle both mode switching (`/irb`) and one-off execution (`/irb puts 1+1`)
- Ensure behavior is consistent with other command patterns

#### 4. IRB Configuration

- Configure IRB appearance to match the REPL's style
- Set appropriate configuration options:
  ```ruby
  IRB.conf[:PROMPT] = custom_prompt
  IRB.conf[:SAVE_HISTORY] = 1000
  IRB.conf[:USE_READLINE] = true
  ```

#### 5. Error Handling

- Capture IRB errors and add them to context
- Ensure proper display of errors to user
- Prevent IRB errors from affecting REPL stability

#### 6. Exit/Mode Switching

- Prevent IRB's own exit commands from closing the application
- Handle mode switching correctly
- Implement clean transitions between modes

#### 7. Context Separation

- Ensure Ruby variables don't leak between modes
- Consider security implications of persistent Ruby execution

## Rails Integration

### Integration Strategy

1. Create a Rails engine or Railtie in the gem
2. Provide a generator that creates a custom `bin/console` replacement
3. Hook into Rails console initialization
4. Add LLM functionality to the Rails environment

### Implementation Steps

1. **Add Rails Engine**:
   ```ruby
   module OllamaRepl
     class Engine < ::Rails::Engine
       isolate_namespace OllamaRepl
       
       initializer "ollama_repl.configure_rails_console" do
         # Hook into console initialization
       end
     end
   end
   ```

2. **Create Generator**:
   ```ruby
   module OllamaRepl
     module Generators
       class InstallGenerator < Rails::Generators::Base
         source_root File.expand_path("templates", __dir__)
         
         def create_console_script
           template "console.tt", "bin/ai_console"
           chmod "bin/ai_console", 0755
         end
       end
     end
   end
   ```

3. **Custom Console Template**:
   ```ruby
   #!/usr/bin/env ruby
   require_relative "../config/boot"
   require "rails/commands/console/console_command"
   require "ollama_repl"

   # Initialize the Rails app
   Rails.application.require_environment!

   # Create and start the OllamaRepl with Rails console integration
   OllamaRepl::RailsConsole.start
   ```

4. **Rails Console Integration**:
   ```ruby
   module OllamaRepl
     class RailsConsole
       def self.start
         repl = OllamaRepl::Repl.new
         repl.register_rails_helpers(Rails.application)
         repl.start
       end
     end
   end
   ```

### Benefits in Rails Environment

- AI assistance with model queries and relationship navigation
- Database schema exploration
- Runtime debugging with application context
- Code generation within the actual application environment
- Contextual help based on the application's codebase
- Testing API endpoints and flows

## Next Steps

1. Create a prototype `IrbMode` implementation
2. Test state persistence between commands
3. Implement proper context capture
4. Explore Rails integration patterns
5. Create a proof-of-concept with a Rails application