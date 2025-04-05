# frozen_string_literal: true

RSpec.describe OllamaRepl do
  it "has a version number" do
    expect(OllamaRepl::VERSION).not_to be nil
  end

  describe ".run" do
    it "creates and runs a new REPL instance" do
      repl_instance = instance_double(OllamaRepl::Repl)
      expect(OllamaRepl::Repl).to receive(:new).and_return(repl_instance)
      expect(repl_instance).to receive(:run)

      OllamaRepl.run
    end
  end
end
