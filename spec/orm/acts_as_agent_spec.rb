# frozen_string_literal: true

require "setup"
require "active_record"
require "sqlite3"
require "stringio"
require "llm/active_record"

RSpec.describe "acts_as_agent" do
  let(:model) { LLM::Test::Harness.build_active_record_model(:spec_active_record_agents) }

  let(:agent) do
    Class.new(model) do
      acts_as_agent provider: :set_provider, context: :set_context, tracer: :set_tracer
      model "gpt-5.4-mini"
      instructions "You are concise."
      concurrency :thread

      private

      def set_provider
        {key: "secret"}
      end

      def set_context
        {mode: :responses, store: false}
      end

      def set_tracer
        LLM::Tracer::Logger.new(llm, io: StringIO.new)
      end
    end
  end

  let(:record) { agent.create!(provider: "openai", model: "gpt-5.4-mini") }
  let(:reload_record) { ->(row) { row.class.find(row.id) } }
  let(:flush_record) { ->(row) { LLM::ActiveRecord::ActsAsAgent::Utils.save(row, row.send(:ctx), row.class.llm_plugin_options) } }

  include_examples "a persisted agent record"
end
