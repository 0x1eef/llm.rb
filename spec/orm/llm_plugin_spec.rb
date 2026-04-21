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
end
