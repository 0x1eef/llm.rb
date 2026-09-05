# frozen_string_literal: true

require "setup"
require "llm/tools"

RSpec.describe "LLM::Tool defaults" do
  let(:tool_class) do
    Class.new(LLM::Tool) do
      name "default-test"
      description "a test tool"
      parameter :literal, Integer, "literal default"
      parameter :symbol, Integer, "symbol default"
      parameter :proc, Integer, "proc default"
      defaults literal: 1,
               symbol: :default_symbol,
               proc: -> { LLM::Tool.max_chars }

      def self.default_symbol
        42
      end
    end
  end
  let(:params) { tool_class.function.params.properties }

  describe "default forms" do
    it "resolves a literal default as-is" do
      expect(params[:literal].default).to eq(1)
    end

    it "resolves a Symbol default against the owner" do
      expect(params[:symbol].default).to eq(42)
    end

    it "resolves a Proc default against the owner" do
      expect(params[:proc].default).to eq(LLM::Tool.max_chars)
    end

    context "when LLM::Tool.max_chars changes" do
      around do |example|
        original = LLM::Tool.max_chars
        LLM::Tool.max_chars(99)
        example.run
      ensure
        LLM::Tool.max_chars(original)
      end

      it "resolves a Proc default lazily" do
        expect(params[:proc].default).to eq(99)
      end
    end
  end
end
