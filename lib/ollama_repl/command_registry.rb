# frozen_string_literal: true

module OllamaRepl
  class CommandRegistry
    def initialize
      @commands = {}
    end

    def register(name, command)
      @commands[name.to_s.downcase] = command
    end

    def get_command(name)
      @commands[name.to_s.downcase]
    end

    def has_command?(name)
      @commands.key?(name.to_s.downcase)
    end

    def command_names
      @commands.keys
    end
  end
end
