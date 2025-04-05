# frozen_string_literal: true

require "spec_helper"
require "ollama_repl/modes/llm_mode"
require "ollama_repl/client"
require "ollama_repl/context_manager"

RSpec.describe OllamaRepl::Modes::LlmMode do
  let(:mock_client) { instance_double(OllamaRepl::Client) }
  let(:mock_context_manager) { instance_double(OllamaRepl::ContextManager, add: nil, for_api: []) }
  let(:mode) { described_class.new(mock_client, mock_context_manager) }

  describe "#prompt" do
    it "returns the correct prompt string" do
      expect(mode.prompt).to eq("🤖 ❯ ")
    end
  end

  describe "#handle_input" do
    let(:user_input) { "Tell me a joke" }
    let(:api_response_chunks) do
      [
        {"message" => {"content" => "Why did the "}},
        {"message" => {"content" => "scarecrow win "}},
        {"message" => {"content" => "an award?"}},
        {"message" => {"content" => "\n"}},
        {"message" => {"content" => "Because he was "}},
        {"message" => {"content" => "outstanding in his field!"}},
        {"done" => true} # Simulate Ollama's done flag if needed
      ]
    end
    let(:full_response) { "Why did the scarecrow win an award?\nBecause he was outstanding in his field!" }

    before do
      # Mock the client's chat method to yield chunks
      allow(mock_client).to receive(:chat).with(mock_context_manager.for_api).and_yield(api_response_chunks[0])
        .and_yield(api_response_chunks[1])
        .and_yield(api_response_chunks[2])
        .and_yield(api_response_chunks[3])
        .and_yield(api_response_chunks[4])
        .and_yield(api_response_chunks[5])
        .and_yield(api_response_chunks[6]) # Yield the 'done' chunk too
      # Capture stdout
      allow($stdout).to receive(:print)
      allow($stdout).to receive(:flush)
      allow($stdout).to receive(:puts) # Capture the final puts ""
    end

    it "adds the user input to the context manager" do
      expect(mock_context_manager).to receive(:add).with("user", user_input)
      mode.handle_input(user_input)
    end

    it "calls the client chat method with the context" do
      expect(mock_client).to receive(:chat).with(mock_context_manager.for_api)
      mode.handle_input(user_input)
    end

    it "prints the streamed response content to stdout" do
      expect($stdout).to receive(:print).with("\nAssistant: ").ordered
      expect($stdout).to receive(:print).with("Why did the ").ordered
      expect($stdout).to receive(:print).with("scarecrow win ").ordered
      expect($stdout).to receive(:print).with("an award?").ordered
      expect($stdout).to receive(:print).with("\n").ordered
      expect($stdout).to receive(:print).with("Because he was ").ordered
      expect($stdout).to receive(:print).with("outstanding in his field!").ordered
      expect($stdout).to receive(:puts).with("") # Final newline (removed ordered)
      mode.handle_input(user_input)
    end

    it "adds the full assistant response to the context manager" do
      # Need to ensure the add call happens *after* the chat block completes
      expect(mock_context_manager).to receive(:add).with("assistant", full_response).ordered
      mode.handle_input(user_input)
    end

    context "when API call fails" do
      let(:api_error) { OllamaRepl::Client::ApiError.new("Connection refused") }

      before do
        allow(mock_client).to receive(:chat).and_raise(api_error)
      end

      it "prints an error message" do
        expect($stdout).to receive(:puts).with("\n[API Error interacting with LLM] #{api_error.message}")
        mode.handle_input(user_input)
      end

      it "does not add an assistant message to context" do
        expect(mock_context_manager).not_to receive(:add).with("assistant", anything)
        # Still adds the user message before the error
        expect(mock_context_manager).to receive(:add).with("user", user_input)
        mode.handle_input(user_input)
      end
    end
  end
end
