# frozen_string_literal: true

require "setup"
require "sequel"
require "sqlite3"
require "stringio"
require "sequel/plugins/llm"

RSpec.describe "plugin :llm" do
  let(:model) { LLM::Test::Harness.build_sequel_model(:spec_sequel_llms) }

  let(:context) do
    Class.new(model) do
      plugin :llm, provider: :set_provider, context: :set_context, tracer: :set_tracer

      private

      def set_provider
        {key: "secret"}
      end

      def set_context
        {store: false}
      end

      def set_tracer
        LLM::Tracer::Logger.new(llm, io: StringIO.new)
      end
    end
  end

  let(:record) { context.create(provider: "openai", model: "gpt-5.4-mini") }
  let(:reload_record) { ->(row) { row.class[row.id] } }
  let(:flush_record) { ->(row) { LLM::Sequel::Plugin::Utils.save(row, row.send(:ctx), row.class.llm_plugin_options) } }

  include_examples "a persisted context record"

  context "with a live OpenAI completion",
          vcr: {cassette_name: "openai/chat/completion_contract"} do
    let(:record) { context.create(provider: "openai", model: "gpt-4.1") }

    it "persists the returned messages" do
      result = record.talk("Hello, world!")
      expect(result).to be_a(LLM::Response)
      expect(reload_record.call(record).messages.last).to be_a(LLM::Message)
      expect(reload_record.call(record).messages.last.content).not_to be_empty
    end
  end
end
