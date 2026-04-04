# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Context do
  let(:ctx) { LLM::Context.new(provider, model:) }

  context "when given openai" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(1050000) }
    end
  end

  context "when given anthropic" do
    let(:provider) { LLM.anthropic(key: "test") }
    let(:model) { "claude-sonnet-4-20250514" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(200000) }
    end
  end

  context "when given google" do
    let(:provider) { LLM.google(key: "test") }
    let(:model) { "gemini-2.5-flash" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(1048576) }
    end
  end

  context "when given deepseek" do
    let(:provider) { LLM.deepseek(key: "test") }
    let(:model) { "deepseek-chat" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(128000) }
    end
  end

  context "when given a model that does not exist" do
    let(:provider) { LLM.deepseek(key: "test") }
    let(:model) { "does-not-exist" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to be_zero }
    end
  end

  context "when configured with responses mode" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:ctx) { LLM::Context.new(provider, model:, mode: :responses) }
    let(:responses) { double }
    let(:response) { double(choices: [LLM::Message.new("assistant", "Paris")]) }

    it "routes talk through the responses API" do
      allow(provider).to receive(:responses).and_return(responses)
      expect(responses).to receive(:create).with("What is the capital of France?", hash_including(model:))
        .and_return(response)
      expect(ctx.talk("What is the capital of France?")).to eq(response)
    end
  end

  context "when a tool call already has a matching tool return" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:tool) do
      Class.new(LLM::Tool) do
        name "system"
        description "run shell commands"
      end
    end

    before do
      ctx.messages << LLM::Message.new("assistant", nil, {
        tools: [tool],
        tool_calls: [
          {id: "call_1", type: "function", function: {name: "system", arguments: {command: "date"}}}
        ]
      })
      ctx.messages << LLM::Message.new("tool", LLM::Function::Return.new("call_1", "system", {success: true}))
    end

    it "returns tool returns from ctx.returns" do
      expect(ctx.returns.map(&:id)).to eq(["call_1"])
    end

    it "does not include the tool call in ctx.functions" do
      expect(ctx.functions).to be_empty
    end
  end
end
