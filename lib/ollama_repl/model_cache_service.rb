# frozen_string_literal: true

module OllamaRepl
  class ModelCacheService
    # Default cache duration in seconds (5 minutes)
    DEFAULT_CACHE_DURATION = 300

    # Initialize with a client and optional cache duration
    def initialize(client, cache_duration: DEFAULT_CACHE_DURATION)
      @client = client
      @cache_duration = cache_duration
      @available_models_cache = nil
      @last_cache_time = nil
    end

    # Get models, optionally forcing a refresh
    def get_models(debug_enabled: false, force_refresh: false)
      current_time = Time.now

      if force_refresh || cache_expired?(current_time)
        refresh_cache(debug_enabled)
      else
        log("Using cached models (#{@available_models_cache.size})", debug_enabled)
      end

      @available_models_cache
    end

    private

    def cache_expired?(current_time)
      @available_models_cache.nil? || @last_cache_time.nil? ||
        (current_time - @last_cache_time) > @cache_duration
    end

    def refresh_cache(debug_enabled)
      log("Refreshing models cache", debug_enabled)
      begin
        @available_models_cache = @client.list_models.sort
        @last_cache_time = Time.now
        log("Cache updated with #{@available_models_cache.size} models", debug_enabled)
      rescue => e
        log("Error fetching models: #{e.message}", debug_enabled)
        @available_models_cache ||= []
      end
    end

    def log(message, debug_enabled)
      puts message if debug_enabled
    end
  end
end
