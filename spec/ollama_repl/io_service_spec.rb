# frozen_string_literal: true

RSpec.describe OllamaRepl::IOService do
  let(:io_service) { described_class.new }

  describe "#display" do
    it "outputs the message to stdout" do
      expect { io_service.display("Test message") }.to output("Test message\n").to_stdout
    end
  end

  describe "#display_error" do
    it "outputs a formatted error message" do
      expect { io_service.display_error("Something went wrong") }.to output("[Error] Something went wrong\n").to_stdout
    end
  end

  describe "#display_api_error" do
    it "outputs a formatted API error message" do
      expect { io_service.display_api_error("API connection failed") }.to output("[API Error] API connection failed\n").to_stdout
    end
  end

  describe "#display_execution_error" do
    it "outputs detailed error information" do
      error = StandardError.new("Test error")
      allow(error).to receive(:backtrace).and_return(["line 1", "line 2"])

      # Without debug
      without_debug = "[Unexpected Error during ruby execution] StandardError: Test error\n"
      expect { io_service.display_execution_error("ruby", error) }.to output(without_debug).to_stdout

      # With debug
      allow(ENV).to receive(:[]).with("DEBUG").and_return("true")
      with_debug = "[Unexpected Error during ruby execution] StandardError: Test error\nline 1\nline 2\n"
      expect { io_service.display_execution_error("ruby", error) }.to output(with_debug).to_stdout
    end
  end

  describe "#prompt" do
    it "uses Readline to get user input" do
      allow(Readline).to receive(:readline).with("Test prompt: ", true).and_return("user input")
      expect(io_service.prompt("Test prompt: ")).to eq("user input")
    end

    it "respects the add_to_history parameter" do
      allow(Readline).to receive(:readline).with("Test prompt: ", false).and_return("user input")
      expect(io_service.prompt("Test prompt: ", false)).to eq("user input")
    end
  end

  describe "#debug" do
    it "outputs debug messages when debug_enabled is true" do
      expect { io_service.debug("Debug message", true) }.to output("Debug message\n").to_stdout
    end

    it "doesn't output debug messages when debug_enabled is false" do
      expect { io_service.debug("Debug message", false) }.not_to output.to_stdout
    end
  end

  describe "#exit_with_error" do
    it "displays an error message and exits with the specified code" do
      expect(io_service).to receive(:display_error).with("Critical error")
      expect(io_service).to receive(:exit).with(2)

      io_service.exit_with_error("Critical error", 2)
    end

    it "uses exit code 1 by default" do
      expect(io_service).to receive(:display_error).with("Critical error")
      expect(io_service).to receive(:exit).with(1)

      io_service.exit_with_error("Critical error")
    end
  end
end
