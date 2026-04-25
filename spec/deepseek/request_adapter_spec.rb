# frozen_string_literal: true

require "setup"
require "llm/providers/deepseek"

RSpec.describe "LLM::DeepSeek::RequestAdapter::Completion" do
  describe "#adapt" do
    it "preserves reasoning content on assistant messages" do
      message = LLM::Message.new("assistant", "answer", reasoning_content: "thought")
      payload = LLM::DeepSeek::RequestAdapter::Completion.new(message).adapt

      expect(payload).to eq(
        role: "assistant",
        content: "answer",
        reasoning_content: "thought"
      )
    end

    it "preserves reasoning content on assistant tool call messages" do
      message = LLM::Message.new("assistant", nil, {
        reasoning_content: "thought",
        original_tool_calls: [{"id" => "call_1"}],
        tool_calls: [{id: "call_1", name: "system", arguments: {command: "date"}}]
      })
      payload = LLM::DeepSeek::RequestAdapter::Completion.new(message).adapt

      expect(payload).to eq(
        role: "assistant",
        content: nil,
        tool_calls: [{"id" => "call_1"}],
        reasoning_content: "thought"
      )
    end
  end
end
