# frozen_string_literal: true

require 'faraday'
require 'faraday/net_http' # Explicitly require adapter
require 'json'
require 'uri'

module OllamaRepl
  class Client
    class ApiError < StandardError; end

    def initialize(host, model)
      @host = host
      @model = model
      @conn = Faraday.new(url: @host) do |faraday|
        faraday.adapter Faraday::Adapter::NetHttp # Use Net::HTTP adapter
        faraday.request :json # Send request body as JSON
        faraday.response :json, content_type: /\bjson$/ # Parse JSON response bodies
        faraday.response :raise_error # Raise errors on 4xx/5xx responses
      end
    end

    def current_model
      @model
    end

    def update_model(new_model)
      @model = new_model
    end

    # Sends messages to the Ollama API and yields streamed response chunks.
    def chat(messages, &block)
      payload = {
        model: @model,
        messages: messages,
        stream: true # Enable streaming
      }
      puts "[Debug] Sending to Ollama (streaming): #{payload.inspect}" if ENV['DEBUG']

      full_response_content = String.new # To accumulate content for potential error reporting (ensure mutable)

      @conn.post('/api/chat', payload) do |req|
        req.options.on_data = proc do |chunk, _overall_received_bytes, _env|
          # Ollama streams JSON objects separated by newlines
          chunk.split("\n").each do |line|
            next if line.strip.empty? # Skip empty lines

            begin
              parsed_chunk = JSON.parse(line)
              full_response_content << parsed_chunk.dig('message', 'content').to_s # Accumulate for errors
              # Yield the parsed chunk for the caller to process
              yield parsed_chunk if block_given?
            rescue JSON::ParserError => e
              # Log or handle partial JSON chunks if necessary, but often indicates end-of-stream issues
              puts "[Debug] JSON parse error on chunk: #{e.message} - Chunk: #{line.inspect}" if ENV['DEBUG']
              # Decide if we should raise or just warn
            end
          end
        end
      end
    rescue Faraday::Error => e
      # Include accumulated content in error if available
      error_details = "API request failed: #{e.message}"
      error_details += " (Response Body accumulated: #{full_response_content})" unless full_response_content.empty?
      error_details += " (Original Faraday Response: #{e.response_body if e.respond_to?(:response_body)})"
      raise ApiError, error_details
    rescue JSON::ParserError => e
      # This might catch errors if the *entire* stream was somehow treated as one JSON doc,
      # though the on_data parsing should handle most cases.
      raise ApiError, "Failed to parse API response stream: #{e.message} (Accumulated: #{full_response_content})"
    rescue NoMethodError, TypeError => e
      # Handle cases where chunk structure is unexpected during accumulation or final processing
      raise ApiError, "Unexpected API response structure in stream: #{e.message} (Accumulated: #{full_response_content})"
    end

    def list_models
      response = @conn.get('/api/tags')
      response.body['models'].map { |m| m['name'] } # Extract model names
    rescue Faraday::Error => e
      raise ApiError, "API request failed to list models: #{e.message} (Response: #{e.response_body if e.respond_to?(:response_body)})"
    rescue JSON::ParserError => e
      raise ApiError, "Failed to parse models API response: #{e.message}"
    rescue NoMethodError, TypeError => e
      raise ApiError, "Unexpected models API response structure: #{e.message} (Body: #{response&.body || 'N/A'})"
    end

    # Check if the API host is reachable and the model exists
    def check_connection_and_model
      # 1. Check connection by listing models (lightweight)
      list_models
      # 2. Check if the specific model exists
      unless list_models.include?(@model)
        raise Error, "Error: Configured model '#{@model}' not found on Ollama host '#{@host}'. Available models: #{list_models.join(', ')}"
      end
      true
    rescue ApiError => e
      raise Error, "Error connecting to Ollama at #{@host}: #{e.message}"
    end
  end
end
