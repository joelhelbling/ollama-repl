# frozen_string_literal: true

RSpec.describe OllamaRepl::ContextManager do
  let(:context_manager) { described_class.new }

  describe "#initialize" do
    it "creates an empty message store" do
      expect(context_manager.all).to eq([])
    end
  end

  describe "#add" do
    it "adds a message with the specified role and content" do
      context_manager.add("user", "Hello")
      expect(context_manager.all).to eq([{role: "user", content: "Hello"}])
    end

    it "adds multiple messages in sequence" do
      context_manager.add("user", "Hello")
      context_manager.add("assistant", "Hi there")
      expect(context_manager.all).to eq([
        {role: "user", content: "Hello"},
        {role: "assistant", content: "Hi there"}
      ])
    end
  end

  describe "#empty?" do
    it "returns true when no messages exist" do
      expect(context_manager.empty?).to be true
    end

    it "returns false when messages exist" do
      context_manager.add("user", "Hello")
      expect(context_manager.empty?).to be false
    end
  end

  describe "#size and #length" do
    it "returns the correct number of messages" do
      expect(context_manager.size).to eq(0)
      expect(context_manager.length).to eq(0)

      context_manager.add("user", "Hello")
      expect(context_manager.size).to eq(1)
      expect(context_manager.length).to eq(1)

      context_manager.add("assistant", "Hi there")
      expect(context_manager.size).to eq(2)
      expect(context_manager.length).to eq(2)
    end
  end

  describe "#clear" do
    it "removes all messages" do
      context_manager.add("user", "Hello")
      context_manager.add("assistant", "Hi there")
      expect(context_manager.size).to eq(2)

      context_manager.clear
      expect(context_manager.size).to eq(0)
      expect(context_manager.empty?).to be true
    end
  end

  describe "#for_api" do
    it "returns the messages in the correct format for the API" do
      context_manager.add("user", "Hello")
      context_manager.add("assistant", "Hi there")

      expect(context_manager.for_api).to eq([
        {role: "user", content: "Hello"},
        {role: "assistant", content: "Hi there"}
      ])
    end
  end
end
