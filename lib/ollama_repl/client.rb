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

    def chat(messages)
      payload = {
        model: @model,
        messages: messages,
        stream: false # Keep it simple for now
      }
      puts "[Debug] Sending to Ollama: #{payload.inspect}" if ENV['DEBUG']
      response = @conn.post('/api/chat', payload)
      puts "[Debug] Received from Ollama: #{response.body.inspect}" if ENV['DEBUG']
      response.body['message']['content'] # Extract content
    rescue Faraday::Error => e
      raise ApiError, "API request failed: #{e.message} (Response: #{e.response_body if e.respond_to?(:response_body)})"
    rescue JSON::ParserError => e
      raise ApiError, "Failed to parse API response: #{e.message}"
    rescue NoMethodError, TypeError => e
      # Handle cases where response structure is unexpected
      raise ApiError, "Unexpected API response structure: #{e.message} (Body: #{response&.body || 'N/A'})"
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
