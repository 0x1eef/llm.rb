# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Tracer::Langsmith do
  let(:provider) { LLM::OpenAI.new }
  let(:tracer) { described_class.new(provider) }
  let(:openai) do
    Class.new do
      def initialize
        @host = "api.openai.com"
        @port = 443
      end
    end
  end

  before { stub_const("LLM::OpenAI", openai) }

  describe "#start_trace" do
    before do
      tracer.start_trace(trace_group_id: "turn-123", metadata: {turn_id: 123})
    end

    it "merges trace metadata into the current extra bag" do
      expect(tracer.current_extra[:metadata]).to eq({turn_id: 123})
    end
  end

  describe "#stop_trace" do
    before do
      tracer.start_trace(trace_group_id: "turn-123", metadata: {turn_id: 123})
      tracer.stop_trace
    end

    it "clears thread-local extra metadata" do
      expect(tracer.current_extra[:metadata]).to eq({})
    end

    it "returns self" do
      expect(tracer.stop_trace).to equal(tracer)
    end
  end
end
