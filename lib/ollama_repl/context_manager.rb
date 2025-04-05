# frozen_string_literal: true

module OllamaRepl
  class ContextManager
    def initialize
      @messages = [] # Conversation history
    end

    def add(role, content)
      @messages << {role: role, content: content}
    end

    def all
      @messages
    end

    def empty?
      @messages.empty?
    end

    def size
      @messages.length
    end

    alias_method :length, :size

    def clear
      @messages.clear
    end

    def for_api
      @messages
    end
  end
end
