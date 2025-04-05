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