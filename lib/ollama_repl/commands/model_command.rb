# frozen_string_literal: true

require_relative "command"

module OllamaRepl
  module Commands
    class ModelCommand < Command
      def initialize(repl, io_service)
        @repl = repl
        @io_service = io_service
      end

      def execute(args, context)
        # Use our cached models for consistent behavior with tab completion
        debug_enabled = ENV["DEBUG"] == "true"
        available_models = @repl.get_available_models(debug_enabled)

        if args.nil? || args.empty?
          # List models
          if available_models.empty?
            @io_service.display("No models available on the Ollama host.")
          else
            @io_service.display("Available models:")
            available_models.each { |m| @io_service.display("- #{m}") }
            @io_service.display("\nCurrent model: #{@repl.client.current_model}")
            @io_service.display("\nTip: Type '/model' followed by at least 3 characters and press Tab for autocompletion")
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
          @io_service.display("Ambiguous model name '#{target_model}'. Matches:")
          prefix_matches.each { |m| @io_service.display("- #{m}") }
          return
        else
          @io_service.display_error("Model '#{target_model}' not found.")
          if available_models.any?
            @io_service.display("Available models: #{available_models.join(", ")}")
          end
          return
        end

        if chosen_model
          @repl.client.update_model(chosen_model)
          @io_service.display("Model set to '#{chosen_model}'.")
          # Optionally, clear context when changing model? Or inform user context is kept.
          # @io_service.display("Conversation context remains.")
        end
      rescue Client::ApiError => e
        @io_service.display_api_error("Error managing models: #{e.message}")
      end
    end
  end
end
