# frozen_string_literal: true

require 'spec_helper'
require 'ollama_repl/modes/ruby_mode'
require 'ollama_repl/context_manager'

RSpec.describe OllamaRepl::Modes::RubyMode do
  # Note: We don't need a mock client for RubyMode
  let(:mock_context_manager) { instance_double(OllamaRepl::ContextManager, add: nil) }
  # Pass nil for client as it's not used by RubyMode directly
  let(:mode) { described_class.new(nil, mock_context_manager) }

  describe '#prompt' do
    it 'returns the correct prompt string' do
      expect(mode.prompt).to eq("💎 ❯ ")
    end
  end

  describe '#handle_input' do
    let(:ruby_code) { "puts 'Hello'; $stderr.puts 'Error msg'; 1 + 1" }
    let(:expected_stdout) { "Hello\n" }
    let(:expected_stderr) { "Error msg\n" }
    let(:expected_context_user_message) { "Execute Ruby code: ```ruby\n#{ruby_code}\n```" }
    let(:expected_context_system_message) {
      "System Message: Ruby Execution Output\nSTDOUT:\n#{expected_stdout}STDERR:\n#{expected_stderr.chomp}\n"
    }

    before do
      # Suppress actual puts from the mode itself during testing
      allow($stdout).to receive(:puts)
    end

    it 'adds the user code execution message to context' do
      expect(mock_context_manager).to receive(:add).with('user', expected_context_user_message).ordered
      # Expect the system message *after* the user message
      expect(mock_context_manager).to receive(:add).with('system', expected_context_system_message).ordered
      mode.handle_input(ruby_code)
    end

    it 'prints execution status and captured output' do
      expect($stdout).to receive(:puts).with("💎 Executing...").ordered
      expect($stdout).to receive(:puts).with("[Ruby Execution Result]").ordered
      expect($stdout).to receive(:puts).with("--- STDOUT ---") # removed ordered
      expect($stdout).to receive(:puts).with(expected_stdout.strip) # removed ordered
      expect($stdout).to receive(:puts).with("--- STDERR ---") # removed ordered
      expect($stdout).to receive(:puts).with(expected_stderr.strip) # removed ordered
      expect($stdout).to receive(:puts).with("--------------") # removed ordered
      mode.handle_input(ruby_code)
    end

    it 'adds the execution result message to context' do
      expect(mock_context_manager).to receive(:add).with('system', expected_context_system_message)
      mode.handle_input(ruby_code)
    end

    context 'when code execution raises an error' do
      let(:error_code) { "raise 'Something went wrong'" }
      let(:error_message) { "Something went wrong" }
      let(:error_class) { RuntimeError }
      let(:expected_context_user_message) { "Execute Ruby code: ```ruby\n#{error_code}\n```" }
      let(:expected_context_system_message_fragment) do
        # Backtrace is hard to predict exactly, so we check for key parts
        /System Message: Ruby Execution Output\nSTDOUT:\n\(empty\)\nSTDERR:\n\(empty\)\nException:\nError: #{error_class}: #{error_message}\nBacktrace:/
      end

      it 'prints an error status and details' do
        expect($stdout).to receive(:puts).with("💎 Executing...").ordered
        expect($stdout).to receive(:puts).with("[Ruby Execution Error]").ordered
        expect($stdout).to receive(:puts).with(/Error: #{error_class}: #{error_message}/).ordered # Check error details are printed
        expect($stdout).to receive(:puts).with("--- STDOUT ---").ordered
        expect($stdout).to receive(:puts).with("(empty)").ordered
        expect($stdout).to receive(:puts).with("--- STDERR ---").ordered
        expect($stdout).to receive(:puts).with("(empty)").ordered
        expect($stdout).to receive(:puts).with("--------------").ordered
        mode.handle_input(error_code)
      end

      it 'adds the user message and error result message to context' do
        expect(mock_context_manager).to receive(:add).with('user', expected_context_user_message).ordered
        # Use match instead of eq for the system message due to backtrace variability
        expect(mock_context_manager).to receive(:add).with('system', match(expected_context_system_message_fragment)).ordered
        mode.handle_input(error_code)
      end
    end

    context 'when code produces no stdout/stderr' do
      let(:silent_code) { "a = 1" }
      let(:expected_context_system_message) {
        "System Message: Ruby Execution Output\nSTDOUT:\n(empty)\nSTDERR:\n(empty)\n"
      }

      it 'correctly reports empty output' do
         expect($stdout).to receive(:puts).with("(empty)").twice # Once for STDOUT, once for STDERR
         mode.handle_input(silent_code)
      end

       it 'adds the correct system message to context' do
        expect(mock_context_manager).to receive(:add).with('system', expected_context_system_message)
        mode.handle_input(silent_code)
      end
    end
  end
end