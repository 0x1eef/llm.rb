# frozen_string_literal: true

require "setup"
require "active_record"
require "sqlite3"
require "stringio"
require "llm/active_record"

RSpec.describe "acts_as_llm" do
  let(:model) { LLM::Harness.build_active_record_model(:spec_active_record_llms) }

  let(:context) do
    Class.new(model) do
      acts_as_llm provider: :set_provider, context: :set_context, tracer: :set_tracer

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

  let(:record) { context.create!(provider: "openai", model: "gpt-5.4-mini") }
  let(:reload_record) { ->(row) { row.class.find(row.id) } }

  include_examples "a persisted context record"
end
