# frozen_string_literal: true

RSpec.describe OllamaRepl::Client do
  let(:host) { "http://localhost:11434" }
  let(:model) { "llama3" }
  let(:client) { described_class.new(host, model) }

  describe "#initialize" do
    it "sets the host and model" do
      expect(client.current_model).to eq(model)
    end
  end

  describe "#update_model" do
    it "updates the current model" do
      client.update_model("llama2")
      expect(client.current_model).to eq("llama2")
    end
  end

  describe "#list_models" do
    before do
      stub_ollama_model_list(host, ["llama3", "llama2", "mistral"])
    end

    it "returns a list of available models" do
      expect(client.list_models).to eq(["llama3", "llama2", "mistral"])
    end

    context "when the API call fails" do
      before do
        stub_request(:get, "#{host}/api/tags")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises an ApiError" do
        expect { client.list_models }.to raise_error(OllamaRepl::Client::ApiError)
      end
    end
  end

  describe "#chat" do
    let(:messages) { [{role: "user", content: "Hello"}] }
    let(:response_chunks) do
      [
        {
          "message" => {"role" => "assistant", "content" => "Hello"},
          "done" => false
        },
        {
          "message" => {"role" => "assistant", "content" => " there!"},
          "done" => true
        }
      ]
    end

    before do
      stub_ollama_chat_streaming(host, model, response_chunks)
    end

    it "yields each response chunk" do
      chunks = []
      client.chat(messages) do |chunk|
        chunks << chunk
      end
      expect(chunks).to eq(response_chunks)
    end

    context "when the API call fails" do
      before do
        stub_request(:post, "#{host}/api/chat")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises an ApiError" do
        expect { client.chat(messages) {} }.to raise_error(OllamaRepl::Client::ApiError)
      end
    end
  end

  describe "#check_connection_and_model" do
    context "when the model exists" do
      before do
        stub_ollama_model_list(host, ["llama3", "llama2"])
      end

      it "returns true" do
        expect(client.check_connection_and_model).to be true
      end
    end

    context "when the model does not exist" do
      before do
        stub_ollama_model_list(host, ["llama2", "mistral"])
      end

      it "raises a ModelNotFoundError" do
        expect { client.check_connection_and_model }.to raise_error(OllamaRepl::Client::ModelNotFoundError)
      end
    end

    context "when the connection fails" do
      before do
        stub_request(:get, "#{host}/api/tags")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "raises an Error" do
        expect { client.check_connection_and_model }.to raise_error(OllamaRepl::Error)
      end
    end
  end
end
