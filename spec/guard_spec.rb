# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Guard do
  let(:provider) { LLM.openai(key: "test") }
  let(:ctx) { LLM::Context.new(provider) }
  let(:tool) do
    Class.new(LLM::Tool) do
      name "echo"
      description "Echo a value"
      param :value, String, "Value", required: true
      def call(value:) = {value:}
    end
  end

  describe LLM::Guard::Null do
    it "never blocks" do
      expect(described_class.new(ctx).call).to be_nil
    end

    it "is the default guard" do
      expect(ctx.guard).to eq(LLM::Guard::Null)
    end
  end

  describe LLM::Guard::Loop do
    before do
      3.times do
        ctx.messages << LLM::Message.new("assistant", nil, {
          tools: [tool],
          tool_calls: [
            {id: "call_x", name: "echo", arguments: {"value" => "hello"}}
          ]
        })
      end
    end

    it "warns on a repeated tool-call pattern" do
      expect(described_class.new(ctx).call).to include("Repeated tool-call pattern")
    end

    it "respects a custom threshold" do
      expect(described_class.new(ctx).call(threshold: 4)).to be_nil
    end
  end

  describe "context wiring" do
    it "uses the loop guard when configured with a class" do
      expect(LLM::Context.new(provider, guard: LLM::Guard::Loop).guard).to eq(LLM::Guard::Loop)
    end

    it "keeps a custom guard class" do
      guard = Class.new(LLM::Guard) do
        def call(**)
          "stop"
        end
      end
      expect(LLM::Context.new(provider, guard:).guard).to eq(guard)
    end

    it "passes guard_options to the guard" do
      threshold = nil
      guard = Class.new(LLM::Guard) do
        define_method(:call) do |**opts|
          threshold = opts[:threshold]
          nil
        end
      end
      ctx = LLM::Context.new(provider, guard:, guard_options: {threshold: 5})
      ctx.guard.new(ctx).call(**ctx.instance_variable_get(:@guard)[:options])
      expect(threshold).to eq(5)
    end
  end
end
