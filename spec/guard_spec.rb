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
  let(:function) { tool.function.tap { |fn| fn.id = "call_1" } }

  describe LLM::Guard::Null do
    it "never blocks" do
      expect(described_class.new(ctx).call(function:)).to be_nil
    end

    it "is the default guard" do
      expect(ctx.guard).to eq(LLM::Guard::Null)
    end
  end

  describe "context wiring" do
    it "keeps a custom guard class" do
      guard = Class.new(LLM::Guard) do
        def call(function:, **)
          "stop"
        end
      end
      expect(LLM::Context.new(provider, guard:).guard).to eq(guard)
    end

    it "passes guard_options to the guard" do
      threshold = nil
      guard = Class.new(LLM::Guard) do
        define_method(:call) do |function:, **opts|
          threshold = opts[:threshold]
          nil
        end
      end
      ctx = LLM::Context.new(provider, guard:, guard_options: {threshold: 5})
      ctx.guard.new(ctx).call(function:, **ctx.instance_variable_get(:@guard)[:options])
      expect(threshold).to eq(5)
    end
  end
end
