# frozen_string_literal: true

RSpec.describe OllamaRepl::CommandHandler do
  let(:repl) { instance_double("OllamaRepl::Repl") }
  let(:context_manager) { instance_double("OllamaRepl::ContextManager") }
  let(:io_service) { instance_double("OllamaRepl::IOService") }
  let(:command_handler) { described_class.new(repl, context_manager, io_service) }

  describe "#handle" do
    before do
      # Set up the necessary mocks for the REPL instance
      allow(repl).to receive(:client).and_return(double("OllamaRepl::Client"))
      allow(repl).to receive(:run_in_mode)
      allow(repl).to receive(:switch_mode)
      allow(repl).to receive(:add_message)
      allow(repl).to receive(:get_available_models).and_return(["llama3", "llama2"])

      # Allow io_service methods that will be called
      allow(io_service).to receive(:display)
      allow(io_service).to receive(:display_error)
      allow(io_service).to receive(:display_api_error)
    end

    context "with /llm command" do
      it "switches to LLM mode when no args" do
        expect(repl).to receive(:switch_mode).with(:llm)
        command_handler.handle("/llm")
      end

      it "sends a single LLM prompt when args are provided" do
        expect(repl).to receive(:run_in_mode).with(:llm, "Hello")
        command_handler.handle("/llm Hello")
      end
    end

    context "with /ruby command" do
      it "switches to Ruby mode when no args" do
        expect(repl).to receive(:switch_mode).with(:ruby)
        command_handler.handle("/ruby")
      end

      it "executes a single Ruby code when args are provided" do
        expect(repl).to receive(:run_in_mode).with(:ruby, "puts 'Hello'")
        command_handler.handle("/ruby puts 'Hello'")
      end
    end

    context "with /shell command" do
      it "switches to Shell mode when no args" do
        expect(repl).to receive(:switch_mode).with(:shell)
        command_handler.handle("/shell")
      end

      it "executes a single shell command when args are provided" do
        expect(repl).to receive(:run_in_mode).with(:shell, "ls -la")
        command_handler.handle("/shell ls -la")
      end
    end

    context "with /file command" do
      before do
        allow(File).to receive(:expand_path).and_return("/path/to/file.rb")
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:readable?).and_return(true)
        allow(File).to receive(:read).and_return("puts 'Hello'")
        allow(File).to receive(:basename).and_return("file.rb")
        allow(File).to receive(:extname).and_return(".rb")
      end

      it "adds file content to context" do
        expect(repl).to receive(:add_message).with("system", instance_of(String))
        command_handler.handle("/file /path/to/file.rb")
      end

      it "shows an error when file not found" do
        allow(File).to receive(:exist?).and_return(false)
        expect(io_service).to receive(:display_error).with(/File not found/)
        command_handler.handle("/file /path/to/file.rb")
      end

      it "shows usage info when no args" do
        expect(io_service).to receive(:display).with(/Usage: \/file/)
        command_handler.handle("/file")
      end
    end

    context "with /model command" do
      let(:client) { instance_double("OllamaRepl::Client") }

      before do
        allow(repl).to receive(:client).and_return(client)
        allow(client).to receive(:update_model)
        allow(client).to receive(:current_model).and_return("llama3")
      end

      it "lists models when no args" do
        expect(io_service).to receive(:display).with(/Available models:/).at_least(:once)
        command_handler.handle("/model")
      end

      it "updates the model when a valid model is provided" do
        expect(client).to receive(:update_model).with("llama2")
        expect(io_service).to receive(:display).with(/Model set to/)
        command_handler.handle("/model llama2")
      end

      it "shows an error when an ambiguous model name is provided" do
        # This would match both llama2 and llama3
        expect(io_service).to receive(:display).with(/Ambiguous model name/)
        command_handler.handle("/model llama")
      end
    end

    context "with /context command" do
      before do
        allow(context_manager).to receive(:empty?).and_return(false)
        allow(context_manager).to receive(:all).and_return([
          {role: "user", content: "Hello"},
          {role: "assistant", content: "Hi there"}
        ])
        allow(context_manager).to receive(:length).and_return(2)
      end

      it "displays the conversation context" do
        expect(io_service).to receive(:display).with(/--- Conversation Context ---/)
        command_handler.handle("/context")
      end
    end

    context "with /clear command" do
      before do
        # Simulate user confirmation
        allow($stdin).to receive(:gets).and_return("y\n")
        allow(context_manager).to receive(:clear)
      end

      it "clears the context after confirmation" do
        expect(context_manager).to receive(:clear)
        expect(io_service).to receive(:display).with(/Conversation context cleared/)
        command_handler.handle("/clear")
      end

      it "does not clear the context if not confirmed" do
        allow($stdin).to receive(:gets).and_return("n\n")
        expect(context_manager).not_to receive(:clear)
        expect(io_service).to receive(:display).with(/Clear context cancelled/)
        command_handler.handle("/clear")
      end
    end

    context "with /help command" do
      it "displays help information" do
        expect(io_service).to receive(:display).with(/--- Ollama REPL Help ---/)
        command_handler.handle("/help")
      end
    end

    context "with unknown command" do
      it "shows an error message" do
        expect(io_service).to receive(:display).with(/Unknown command/)
        command_handler.handle("/unknown")
      end
    end
  end
end
