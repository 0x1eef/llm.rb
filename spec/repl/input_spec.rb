# frozen_string_literal: true

require "setup"
require "llm/repl"

RSpec.describe LLM::Repl::Input do
  let(:llm) { LLM.deepseek(key: ENV["test"]) }
  let(:agent) { LLM::Agent.new(llm) }
  let(:input) { described_class.new(agent) }

  describe "#restore" do
    let(:buffer) { "" }
    let(:copy) { "" }
    let(:cursor) { 0 }

    before do
      input.instance_variable_set(:@buffer, buffer)
      input.instance_variable_set(:@copy, copy)
      input.instance_variable_set(:@cursor, cursor)
    end

    context "when we're at the end of the string" do
      let(:buffer) { +"hello" }
      let(:copy) { " world" }
      let(:cursor) { buffer.size }

      it "appends to the end of the string" do
        input.restore
        expect(input.buffer).to eq("hello world")
      end
    end

    context "when we're inside the string " do
      let(:buffer) { +"hello" }
      let(:copy) { " world" }
      let(:cursor) { 3 }

      it "inserts the string in-place" do
        input.restore
        expect(input.buffer).to eq("hel worldlo")
      end
    end
  end
end
