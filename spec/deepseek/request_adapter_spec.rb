# frozen_string_literal: true

require "setup"
require "llm/providers/deepseek"

RSpec.describe "LLM::DeepSeek::RequestAdapter::Completion" do
  describe "#adapt" do
    subject(:payload) { LLM::DeepSeek::RequestAdapter::Completion.new(message).adapt }

    context "with assistant content" do
      let(:message) do
        LLM::Message.new("assistant", "answer", reasoning_content: "thought")
      end

      it "preserves reasoning content" do
        expect(payload).to eq(
          role: "assistant",
          content: "answer",
          reasoning_content: "thought"
        )
      end
    end

    context "with assistant tool calls" do
      let(:message) do
        LLM::Message.new("assistant", nil, {
          reasoning_content: "thought",
          original_tool_calls: [{"id" => "call_1"}],
          tool_calls: [{id: "call_1", name: "system", arguments: {command: "date"}}]
        })
      end

      it "preserves nil content" do
        expect(payload[:content]).to be_nil
      end

      it "normalizes tool calls" do
        expect(payload[:tool_calls]).to eq([{"id" => "call_1"}])
      end

      it "preserves reasoning content" do
        expect(payload[:reasoning_content]).to eq("thought")
      end
    end
  end
end
