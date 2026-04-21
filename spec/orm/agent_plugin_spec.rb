# frozen_string_literal: true

require "setup"
require "sequel"
require "sqlite3"
require "stringio"
require "sequel/plugins/agent"

RSpec.describe "plugin :agent" do
  let(:model) { LLM::Harness.build_sequel_model(:spec_sequel_agents) }

  let(:agent) do
    Class.new(model) do
      plugin :agent, provider: :set_provider, context: :set_context, tracer: :set_tracer
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

  let(:record) { agent.create(provider: "openai", model: "gpt-5.4-mini") }
  let(:reload_record) { ->(row) { row.class[row.id] } }

  include_examples "a persisted agent record"
end
