# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::OpenAI::ResponseAdapter::Completion" do
  let(:body) { LLM::Object.from(choices: [], usage:, model: "test-model") }
  let(:http_response) { Struct.new(:body).new(body) }
  let(:response) { LLM::Response.new(http_response) }
  let(:completion) { LLM::OpenAI::ResponseAdapter.adapt(response, type: :completion) }

  context "when usage is nil" do
    let(:usage) { nil }

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

  context "when usage is provided" do
    let(:usage) { LLM::Object.from(prompt_tokens: 10, completion_tokens: 20, total_tokens: 30) }

    it "returns correct input tokens" do
      expect(completion.input_tokens).to eq(10)
    end

    it "returns correct output tokens" do
      expect(completion.output_tokens).to eq(20)
    end

    it "returns correct total tokens" do
      expect(completion.total_tokens).to eq(30)
    end
  end
end
