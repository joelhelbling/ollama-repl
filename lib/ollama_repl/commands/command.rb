# frozen_string_literal: true

module OllamaRepl
  module Commands
    class Command
      def execute(args, context)
        raise NotImplementedError, "#{self.class.name} must implement #execute"
      end
    end
  end
end
