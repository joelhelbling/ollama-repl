# frozen_string_literal: true

# Stdlib requires
require "pathname"
require "readline"
require "json"
require "stringio"
require "uri"

# Gem requires
require "dotenv/load"
require "faraday"
require "faraday/net_http"

# Internal requires
require_relative "ollama_repl/version"
require_relative "ollama_repl/config"
require_relative "ollama_repl/client"
require_relative "ollama_repl/model_cache_service"
require_relative "ollama_repl/repl"

module OllamaRepl
  class Error < StandardError; end

  def self.run
    Repl.new.run
  end
end
