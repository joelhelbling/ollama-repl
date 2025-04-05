# frozen_string_literal: true

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
