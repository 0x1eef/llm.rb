# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Registry do
  let(:registry) { LLM::Registry.for(provider) }

  shared_examples "model exists" do |model|
    context "#cost" do
      context "when given the #{model} model" do
        it "returns an object" do
          expect(
            registry.cost(model:)
          ).to be_instance_of(LLM::Object)
        end
      end
    end
  end

  shared_examples "fallback exists" do |model, fallback|
    context "#cost" do
      context "when given the #{model} model" do
        it "returns the #{fallback} cost object" do
          expect(
            registry.cost(model:)
          ).to eq(registry.cost(model: fallback))
        end
      end
    end
  end

  context "when given openai" do
    let(:provider) { :openai }

    include_examples "model exists", "gpt-4.1"
    include_examples "model exists", "gpt-5.3-codex"
    include_examples "fallback exists", "gpt-4.1-2025-01-01", "gpt-4.1"
    include_examples "fallback exists", "gpt-4-0613", "gpt-4"
  end

  context "when given google" do
    let(:provider) { :google }

    include_examples "model exists", "gemini-3.1-pro-preview-customtools"
    include_examples "model exists", "gemini-embedding-001"
  end

  context "when given anthropic" do
    let(:provider) { :anthropic }

    include_examples "model exists", "claude-opus-5"
    include_examples "model exists", "claude-haiku-4-5-20251001"
  end

  context "when given deepseek" do
    let(:provider) { :deepseek }

    include_examples "model exists", "deepseek-chat"
    include_examples "model exists", "deepseek-reasoner"
  end

  context "when given xai" do
    let(:provider) { :xai }

    include_examples "model exists", "grok-4.3"
    include_examples "model exists", "grok-4.20-0309-non-reasoning"
  end

  context "when given zai" do
    let(:provider) { :zai }

    include_examples "model exists", "glm-5"
    include_examples "model exists", "glm-4.5-air"
  end

  context "when given moonshot" do
    let(:provider) { :moonshot }

    include_examples "model exists", "kimi-k3"
    include_examples "model exists", "kimi-k2.5"
  end

  context "when given alibaba" do
    let(:provider) { :alibaba }

    include_examples "model exists", "qwen3.6-flash"
    include_examples "model exists", "qwen3-max"
  end

  context "when given bedrock" do
    let(:provider) { :bedrock }

    include_examples "model exists", "anthropic.claude-sonnet-4-5-20250929-v1:0"
    include_examples "model exists", "meta.llama3-3-70b-instruct-v1:0"
  end

  describe "#keys" do
    let(:provider) { :openai }

    subject { registry.keys }

    it "returns the model names" do
      expect(subject).to include("gpt-4.1")
    end
  end

  describe "#models" do
    let(:provider) { :openai }

    subject(:models) { registry.models }

    it "returns registry models" do
      expect(models).to all(be_a(LLM::Registry::Model))
    end

    it "exposes the model ids" do
      expect(models.map(&:id)).to include("gpt-4.1")
    end
  end

  describe LLM::Registry::Model do
    subject(:model) { LLM::Registry.for(:openai).models.find { _1.id == "gpt-4.1" } }

    it "exposes a display name" do
      expect(model.name).to be_a(String)
    end

    it "exposes the context window" do
      expect(model.context_window).to be_a(Integer)
    end

    it "exposes the cost object" do
      expect(model.cost).to be_a(LLM::Object)
    end
  end
end
