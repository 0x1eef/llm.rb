# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Session do
  let(:session) { LLM::Session.new(provider, model:) }

  context "when given openai" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }

    context "#context_window" do
      subject { session.context_window }
      it { is_expected.to eq(1050000) }
    end
  end

  context "when given anthropic" do
    let(:provider) { LLM.anthropic(key: "test") }
    let(:model) { "claude-sonnet-4-20250514" }

    context "#context_window" do
      subject { session.context_window }
      it { is_expected.to eq(200000) }
    end
  end

  context "when given google" do
    let(:provider) { LLM.google(key: "test") }
    let(:model) { "gemini-2.5-flash" }

    context "#context_window" do
      subject { session.context_window }
      it { is_expected.to eq(1048576) }
    end
  end

  context "when given deepseek" do
    let(:provider) { LLM.deepseek(key: "test") }
    let(:model) { "deepseek-chat" }

    context "#context_window" do
      subject { session.context_window }
      it { is_expected.to eq(128000) }
    end
  end

  context "when given a model that does not exist" do
    let(:provider) { LLM.deepseek(key: "test") }
    let(:model) { "does-not-exist" }

    context "#context_window" do
      subject { session.context_window }
      it { is_expected.to be_zero }
    end
  end
end
