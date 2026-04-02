# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Message do
  describe "#reasoning_content" do
    subject(:message) do
      described_class.new("assistant", "answer", reasoning_content: "thought")
    end

    it "returns the reasoning content" do
      expect(message.reasoning_content).to eq("thought")
    end

    it "includes reasoning content in the hash representation" do
      expect(message.to_h[:reasoning_content]).to eq("thought")
    end
  end
end
