# frozen_string_literal: true

RSpec.describe OllamaRepl::Config do
  describe ".ollama_host" do
    it "returns the default host when OLLAMA_HOST env var is not set" do
      with_env('OLLAMA_HOST' => nil) do
        expect(described_class.ollama_host).to eq('http://localhost:11434')
      end
    end
    
    it "returns the configured host when OLLAMA_HOST env var is set" do
      with_env('OLLAMA_HOST' => 'http://example.com:11434') do
        expect(described_class.ollama_host).to eq('http://example.com:11434')
      end
    end
    
    it "removes trailing slashes from the host URL" do
      with_env('OLLAMA_HOST' => 'http://example.com:11434/') do
        expect(described_class.ollama_host).to eq('http://example.com:11434')
      end
    end
  end
  
  describe ".ollama_model" do
    it "returns the configured model when OLLAMA_MODEL env var is set" do
      with_env('OLLAMA_MODEL' => 'llama3') do
        expect(described_class.ollama_model).to eq('llama3')
      end
    end
    
    it "returns nil when OLLAMA_MODEL env var is not set" do
      with_env('OLLAMA_MODEL' => nil) do
        expect(described_class.ollama_model).to be_nil
      end
    end
  end
  
  describe ".validate_config!" do
    context "when OLLAMA_MODEL is not set" do
      it "raises an error" do
        with_env('OLLAMA_MODEL' => nil) do
          expect { described_class.validate_config! }.to raise_error(OllamaRepl::Error)
        end
      end
    end
    
    context "when OLLAMA_HOST is invalid" do
      it "raises an error" do
        with_env('OLLAMA_MODEL' => 'llama3', 'OLLAMA_HOST' => 'invalid-url') do
          expect { described_class.validate_config! }.to raise_error(OllamaRepl::Error)
        end
      end
    end
    
    context "when configuration is valid" do
      it "does not raise an error" do
        with_env('OLLAMA_MODEL' => 'llama3', 'OLLAMA_HOST' => 'http://localhost:11434') do
          expect { described_class.validate_config! }.not_to raise_error
        end
      end
    end
  end
end