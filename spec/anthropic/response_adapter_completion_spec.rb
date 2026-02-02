# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Anthropic::ResponseAdapter::Completion" do
  let(:body) { LLM::Object.from(content: [], usage: nil, model: "test-model") }
  let(:http_response) { Struct.new(:body).new(body) }
  let(:response) { LLM::Response.new(http_response) }
  let(:completion) { LLM::Anthropic::ResponseAdapter.adapt(response, type: :completion) }

  context "when usage is nil" do
    it "returns 0 for input tokens" do
      expect(completion.input_tokens).to eq(0)
    end

    it "returns 0 for output tokens" do
      expect(completion.output_tokens).to eq(0)
    end

    it "returns 0 for total tokens" do
      expect(completion.total_tokens).to eq(0)
    end
  end
end
