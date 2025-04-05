# frozen_string_literal: true

RSpec.describe OllamaRepl::Repl do
  before(:each) do
    # Mock Config
    allow(OllamaRepl::Config).to receive(:validate_config!)
    allow(OllamaRepl::Config).to receive(:ollama_host).and_return("http://localhost:11434")
    allow(OllamaRepl::Config).to receive(:ollama_model).and_return("llama3")

    # Mock Client
    @client = instance_double("OllamaRepl::Client")
    allow(OllamaRepl::Client).to receive(:new).and_return(@client)
    allow(@client).to receive(:current_model).and_return("llama3")
    allow(@client).to receive(:check_connection_and_model).and_return(true)
    allow(@client).to receive(:list_models).and_return(["llama3", "llama2"])
    
    # Mock ModelCacheService
    @model_cache_service = instance_double("OllamaRepl::ModelCacheService")
    allow(OllamaRepl::ModelCacheService).to receive(:new).and_return(@model_cache_service)
    allow(@model_cache_service).to receive(:get_models).and_return(["llama3", "llama2"])
    
    # Mock Readline to avoid terminal interaction
    allow(Readline).to receive(:readline).and_return("test input", nil)
    allow(Readline::HISTORY).to receive(:push)
    
    # Suppress output during tests
    allow($stdout).to receive(:write)
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:print)
    allow($stdout).to receive(:flush)
  end

  let(:repl) { OllamaRepl::Repl.new }

  describe "#initialize" do
    it "initializes with default settings" do
      expect(repl.client).to eq(@client)
      expect(repl.context_manager).to be_a(OllamaRepl::ContextManager)
    end
    
    it "exits when a configuration error occurs" do
      allow(OllamaRepl::Config).to receive(:validate_config!).and_raise(OllamaRepl::Error, "Test error")
      expect { OllamaRepl::Repl.new }.to raise_error(SystemExit)
    end
  end

  describe "#current_prompt" do
    it "returns the LLM prompt by default" do
      expect(repl.current_prompt).to eq("🤖 ❯ ")
    end
    
    it "returns different prompts based on mode" do
      repl.switch_mode(:ruby)
      expect(repl.current_prompt).to eq("💎 ❯ ")
      
      repl.switch_mode(:shell)
      expect(repl.current_prompt).to eq("🐚 ❯ ")
    end
  end

  describe "#switch_mode" do
    it "changes the current mode" do
      original_prompt = repl.current_prompt
      repl.switch_mode(:ruby)
      expect(repl.current_prompt).not_to eq(original_prompt)
    end
  end
  
  describe "#process_input" do
    it "ignores empty input" do
      # Just verify it doesn't raise an error
      expect { repl.process_input("") }.not_to raise_error
    end
    
    it "delegates commands to the command handler" do
      expect_any_instance_of(OllamaRepl::CommandHandler).to receive(:handle).with("/help")
      repl.process_input("/help")
    end
  end
  
  describe "#add_message" do
    it "adds a message to the context manager" do
      expect(repl.context_manager).to receive(:add).with("user", "Hello")
      repl.add_message("user", "Hello")
    end
  end
  
  describe "#get_available_models" do
    it "delegates to the model cache service" do
      # Expect delegation with correct parameters
      expect(@model_cache_service).to receive(:get_models).with(debug_enabled: true).and_return(["llama3", "llama2"])
      
      result = repl.get_available_models(true)
      expect(result).to eq(["llama3", "llama2"])
    end
  end
  
  # The tests for methods that have been moved to mode classes are removed
  # This includes handle_llm_input, capture_ruby_execution, and capture_shell_execution
end