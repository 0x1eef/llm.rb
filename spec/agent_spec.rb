# frozen_string_literal: true

require_relative "setup"

RSpec.describe LLM::Agent do
  let!(:provider) { LLM.openai(key: "test") }

  shared_examples "agent behavior" do |provider|
    context "when given a provider" do
      schema = Class.new(LLM::Schema) do
        property :answer, String, "Answer", required: true
      end

      tool = Class.new(LLM::Tool) do
        name "echo"
        description "Echo a value"
        param :value, String, "Value", required: true
        def call(value:) = {value:}
      end

      let(:agent) do
        Class.new(described_class) do
          model "gpt-4.1"
          instructions "You are helpful"
          tools tool
          schema schema
        end
      end

      describe "DSL defaults" do
        it "passes the defaults to the context" do
          expect(LLM::Context).to receive(:new).with(
            provider,
            {model: "gpt-4.1", tools: [tool], schema:}
          ).and_call_original
          agent.new(provider)
        end
      end

      describe do
        let(:prompt) do
          LLM::Prompt.new(provider) do
            system "You are helpful"
            user "hello"
          end
        end

        let(:agent) do
          super().new(provider)
        end

        it do
          expect(agent.llm).to receive(:complete)
            .with(prompt, instance_of(Hash))
            .and_return(double(choices: [LLM::Message.new("assistant", "hello")]))
          agent.talk(prompt)
        end
      end
    end
  end

  include_examples "agent behavior", LLM.openai(key: "test")
  include_examples "agent behavior", LLM.google(key: "test")
  include_examples "agent behavior", LLM.anthropic(key: "test")
  include_examples "agent behavior", LLM.xai(key: "test")
  include_examples "agent behavior", LLM.zai(key: "test")
  include_examples "agent behavior", LLM.deepseek(key: "test")
end
