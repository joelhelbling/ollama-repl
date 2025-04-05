# frozen_string_literal: true

require "spec_helper"
require "ollama_repl/modes/shell_mode"
require "ollama_repl/context_manager"
require "open3" # To mock Open3.capture3

RSpec.describe OllamaRepl::Modes::ShellMode do
  # Note: We don't need a mock client for ShellMode
  let(:mock_context_manager) { instance_double(OllamaRepl::ContextManager, add: nil) }
  # Pass nil for client as it's not used by ShellMode directly
  let(:mode) { described_class.new(nil, mock_context_manager) }

  describe "#prompt" do
    it "returns the correct prompt string" do
      expect(mode.prompt).to eq("🐚 ❯ ")
    end
  end

  describe "#handle_input" do
    let(:shell_command) { "echo 'Hello Shell' && echo 'Error Shell' >&2" }
    let(:expected_stdout) { "Hello Shell\n" }
    let(:expected_stderr) { "Error Shell\n" }
    let(:mock_status_success) { instance_double(Process::Status, success?: true) }
    let(:expected_context_user_message) { "Execute shell command: ```\n#{shell_command}\n```" }
    let(:expected_context_system_message) {
      "System Message: Shell Execution Output\nSTDOUT:\n#{expected_stdout}STDERR:\n#{expected_stderr}\n"
    }

    before do
      # Suppress actual puts from the mode itself during testing
      allow($stdout).to receive(:puts)
      # Mock Open3.capture3 by default to return success
      allow(Open3).to receive(:capture3)
        .with(shell_command)
        .and_return([expected_stdout, expected_stderr, mock_status_success])
    end

    it "adds the user command execution message to context" do
      expect(mock_context_manager).to receive(:add).with("user", expected_context_user_message).ordered
      # Expect the system message *after* the user message
      expect(mock_context_manager).to receive(:add).with("system", expected_context_system_message).ordered
      mode.handle_input(shell_command)
    end

    it "prints execution status and captured output" do
      expect($stdout).to receive(:puts).with("❯ Executing...").ordered
      expect($stdout).to receive(:puts).with("[Shell Execution Result]").ordered
      expect($stdout).to receive(:puts).with("--- STDOUT ---") # removed ordered
      expect($stdout).to receive(:puts).with(expected_stdout.strip) # removed ordered
      expect($stdout).to receive(:puts).with("--- STDERR ---") # removed ordered
      expect($stdout).to receive(:puts).with(expected_stderr.strip) # removed ordered
      expect($stdout).to receive(:puts).with("--------------") # removed ordered
      mode.handle_input(shell_command)
    end

    it "adds the execution result message to context" do
      expect(mock_context_manager).to receive(:add).with("system", expected_context_system_message)
      mode.handle_input(shell_command)
    end

    context "when command execution fails (non-zero exit status)" do
      let(:failed_command) { "ls /nonexistent_directory" }
      let(:expected_stdout_fail) { "" }
      # Stderr often includes the error message from the shell itself
      let(:expected_stderr_fail) { "ls: /nonexistent_directory: No such file or directory" }
      let(:exit_status_code) { 1 }
      let(:mock_status_fail) { instance_double(Process::Status, success?: false, exitstatus: exit_status_code) }
      let(:expected_stderr_with_status) { "#{expected_stderr_fail}\nCommand exited with status: #{exit_status_code}" }
      let(:expected_context_user_message) { "Execute shell command: ```\n#{failed_command}\n```" }
      let(:expected_context_system_message) {
        "System Message: Shell Execution Output\nSTDOUT:\n(empty)\nSTDERR:\n#{expected_stderr_with_status}\n"
      }

      before do
        allow(Open3).to receive(:capture3)
          .with(failed_command)
          .and_return([expected_stdout_fail, expected_stderr_fail, mock_status_fail])
      end

      it "prints execution result (not error) and includes exit status in stderr output" do
        expect($stdout).to receive(:puts).with("❯ Executing...").ordered
        # It's still a "Result" because the command ran, it just failed
        expect($stdout).to receive(:puts).with("[Shell Execution Result]").ordered
        expect($stdout).to receive(:puts).with("--- STDOUT ---") # removed ordered
        expect($stdout).to receive(:puts).with("(empty)") # removed ordered
        expect($stdout).to receive(:puts).with("--- STDERR ---") # removed ordered
        # Check that the combined stderr (original + exit status) is printed
        expect($stdout).to receive(:puts).with(expected_stderr_with_status) # removed ordered
        expect($stdout).to receive(:puts).with("--------------") # removed ordered
        mode.handle_input(failed_command)
      end

      it "adds the user message and result message (with failure details) to context" do
        expect(mock_context_manager).to receive(:add).with("user", expected_context_user_message).ordered
        expect(mock_context_manager).to receive(:add).with("system", expected_context_system_message).ordered
        mode.handle_input(failed_command)
      end
    end

    context "when Open3 itself raises an error (e.g., command not found)" do
      let(:invalid_command) { "invalid_command_name_xyz" }
      let(:error_message) { "No such file or directory - invalid_command_name_xyz" }
      # The specific error class might vary slightly by OS/environment, use StandardError for broader catch
      let(:execution_error) { Errno::ENOENT.new(error_message) }
      let(:expected_stderr_with_exception) { "\nExecution failed: #{error_message}" } # Stderr includes exception msg
      let(:expected_context_user_message) { "Execute shell command: ```\n#{invalid_command}\n```" }
      let(:expected_context_system_message) {
        # Note: Backtrace is not included by default in the system message for shell errors
        "System Message: Shell Execution Output\nSTDOUT:\n(empty)\nSTDERR:\n#{expected_stderr_with_exception}\nException:\nError: #{execution_error.class}: #{execution_error.message}\n"
      }

      before do
        allow(Open3).to receive(:capture3).with(invalid_command).and_raise(execution_error)
      end

      it "prints an error status and details" do
        expect($stdout).to receive(:puts).with("❯ Executing...").ordered
        expect($stdout).to receive(:puts).with("[Shell Execution Error]").ordered
        expect($stdout).to receive(:puts).with(/Error: #{execution_error.class}: #{execution_error.message}/).ordered
        expect($stdout).to receive(:puts).with("--- STDOUT ---") # removed ordered
        expect($stdout).to receive(:puts).with("(empty)") # removed ordered
        expect($stdout).to receive(:puts).with("--- STDERR ---") # removed ordered
        # Check that stderr contains the failure message added in the rescue block
        expect($stdout).to receive(:puts).with("\nExecution failed: #{error_message}") # Expect exact error message
        expect($stdout).to receive(:puts).with("--------------") # removed ordered
        mode.handle_input(invalid_command)
      end

      it "adds the user message and error result message to context" do
        expect(mock_context_manager).to receive(:add).with("user", expected_context_user_message).ordered
        expect(mock_context_manager).to receive(:add).with("system", expected_context_system_message).ordered
        mode.handle_input(invalid_command)
      end
    end
  end
end
