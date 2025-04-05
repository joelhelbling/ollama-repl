# Model Cache Service Implementation Plan

Based on our refactoring analysis, extracting the model caching functionality is a good first step. This document outlines a detailed implementation plan for the Model Cache Service.

## Why Start With Model Cache Service?

1. **Well-Contained Scope**: The model caching functionality is currently isolated within the `get_available_models` method, making it easy to extract without disrupting other parts of the codebase.

2. **Clear Testability Improvement**: The current implementation mixes time-based caching logic with model retrieval, making it difficult to test. Extracting this would immediately improve testability.

3. **Minimal Dependencies**: This refactoring doesn't require other components to be changed first, making it an ideal starting point.

4. **Immediate Value**: Proper caching of models is important for performance and user experience, so improving this component provides immediate value.

## Current Implementation

Current `get_available_models` method in `Repl` class:

```ruby
def get_available_models(debug_enabled = false)
  current_time = Time.now
  
  # Cache models for 5 minutes to avoid excessive API calls
  if @available_models_cache.nil? || @last_cache_time.nil? ||
     (current_time - @last_cache_time) > 300 # 5 minutes
    
    puts "Refreshing models cache" if debug_enabled
    begin
      @available_models_cache = @client.list_models.sort
      @last_cache_time = current_time
      puts "Cache updated with #{@available_models_cache.size} models" if debug_enabled
    rescue => e
      puts "Error fetching models: #{e.message}" if debug_enabled
      @available_models_cache ||= []
    end
  else
    puts "Using cached models (#{@available_models_cache.size})" if debug_enabled
  end
  
  @available_models_cache
end
```

## New Implementation

### 1. Create ModelCacheService class

```ruby
# lib/ollama_repl/model_cache_service.rb
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
```

### 2. Update Repl Class

```ruby
# In lib/ollama_repl/repl.rb

# Add require statement at the top
require_relative 'model_cache_service'

# In the initialize method, add:
def initialize
  Config.validate_config!
  @client = Client.new(Config.ollama_host, Config.ollama_model)
  @context_manager = ContextManager.new
  # Add the model cache service
  @model_cache_service = ModelCacheService.new(@client)
  # Rest of initialization...
  # ...
rescue Error => e # Catch configuration or initial connection errors
  puts "[Error] #{e.message}"
  exit 1
end

# Replace get_available_models with:
def get_available_models(debug_enabled = false)
  @model_cache_service.get_models(debug_enabled: debug_enabled)
end
```

## Testing Plan

### 1. Create ModelCacheService Tests

```ruby
# spec/ollama_repl/model_cache_service_spec.rb
# frozen_string_literal: true

RSpec.describe OllamaRepl::ModelCacheService do
  let(:client) { instance_double("OllamaRepl::Client") }
  let(:models) { ["llama3", "llama2"] }
  let(:service) { described_class.new(client) }

  before do
    allow(client).to receive(:list_models).and_return(models)
  end

  describe "#get_models" do
    it "fetches models from client on first call" do
      expect(client).to receive(:list_models).once.and_return(models)
      result = service.get_models
      expect(result).to eq(models.sort)
    end

    it "uses cached result on subsequent calls" do
      # First call fetches
      service.get_models
      # Second call should use cache
      expect(client).not_to receive(:list_models)
      result = service.get_models
      expect(result).to eq(models.sort)
    end

    it "refreshes cache after expiration" do
      # Set a shorter cache duration for testing
      service = described_class.new(client, cache_duration: 0.01)
      
      # First call fetches
      service.get_models
      
      # Wait for cache to expire
      sleep 0.02
      
      # Second call should fetch again
      expect(client).to receive(:list_models).once.and_return(models)
      result = service.get_models
      expect(result).to eq(models.sort)
    end

    it "forces refresh when requested" do
      # First call fetches
      service.get_models
      
      # Second call with force_refresh should fetch again
      expect(client).to receive(:list_models).once.and_return(models)
      result = service.get_models(force_refresh: true)
      expect(result).to eq(models.sort)
    end

    it "handles errors during model fetching" do
      allow(client).to receive(:list_models).and_raise(StandardError.new("API error"))
      
      # Should not raise error but return empty array
      result = service.get_models
      expect(result).to eq([])
    end

    it "logs debug information when enabled" do
      expect { service.get_models(debug_enabled: true) }.to output(/Refreshing models cache/).to_stdout
    end
  end
end
```

### 2. Update Repl Tests

```ruby
# In spec/ollama_repl/repl_spec.rb

# Add a test for the delegation to ModelCacheService
describe "#get_available_models" do
  it "delegates to the model cache service" do
    mock_cache_service = instance_double("OllamaRepl::ModelCacheService")
    # Set the mock service in the repl instance
    repl.instance_variable_set(:@model_cache_service, mock_cache_service)
    
    # Expect delegation with correct parameters
    expect(mock_cache_service).to receive(:get_models).with(debug_enabled: true).and_return(["model1", "model2"])
    
    result = repl.get_available_models(true)
    expect(result).to eq(["model1", "model2"])
  end
end
```

## Implementation Steps

1. Create the `ModelCacheService` class in a new file
2. Update the `Repl` class to use the new service
3. Write tests for the `ModelCacheService`
4. Update tests for the `Repl` class
5. Run the test suite to ensure everything passes

## Benefits of This Approach

1. **Single Responsibility**: The `ModelCacheService` has one job - managing the model cache
2. **Improved Testability**: We can test caching logic in isolation
3. **Configurable**: Cache duration can be configured
4. **Encapsulated Error Handling**: Error handling is contained within the service
5. **Minimal Changes to Repl**: The `Repl` class barely changes, reducing risk

By starting with this refactoring, we establish a pattern for extracting functionality that can be applied to the other refactorings in our plan.