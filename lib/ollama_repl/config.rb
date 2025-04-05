# frozen_string_literal: true

require "dotenv/load" # Load .env file if present

module OllamaRepl
  module Config
    def self.ollama_host
      # Ensure no trailing slash and handle potential nil
      (ENV["OLLAMA_HOST"] || "http://localhost:11434").chomp("/")
    end

    def self.ollama_model
      ENV["OLLAMA_MODEL"]
    end

    def self.validate_config!
      if ollama_model.nil? || ollama_model.empty?
        raise Error, "Configuration error: OLLAMA_MODEL environment variable must be set."
      end
      # Basic URL check (not exhaustive)
      unless /\Ahttps?:\/\//.match?(ollama_host)
        raise Error, "Configuration error: OLLAMA_HOST must be a valid URL (e.g., http://localhost:11434)."
      end
    end
  end
end
