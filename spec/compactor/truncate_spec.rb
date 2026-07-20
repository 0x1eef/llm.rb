# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Compactor::Truncate do
  subject(:compactor) { described_class.new(ctx) }

  let(:provider) { LLM.openai(key: "test") }
  let(:ctx) { LLM::Context.new(provider) }

  def add_message(role, content, extra = {})
    ctx.messages << LLM::Message.new(role, content, extra)
  end

  def add_tool_call(name, args = {})
    add_message "assistant", "", {tool_calls: [{id: "call_1", name:, arguments: args}]}
  end

  describe "#call" do
    context "when the conversation is shorter than keep" do
      before do
        add_message "user", "first"
        add_message "assistant", "second"
      end

      it { expect(compactor.call(keep: 5)).to be_nil }
      it { expect { compactor.call(keep: 5) }.not_to(change { ctx.messages.to_a }) }

      it "does not mark the context as compacted" do
        compactor.call(keep: 5)
        expect(ctx.compacted?).to be_nil
      end
    end

    context "when the conversation exceeds keep" do
      before do
        add_message "user", "first"
        add_message "assistant", "second"
        add_message "user", "third"
        add_message "assistant", "fourth"
        add_message "user", "fifth"
      end

      it "drops the oldest non-system messages" do
        compactor.call(keep: 3)
        expect(ctx.messages.map(&:content)).to eq(%w[third fourth fifth])
      end

      it "returns the last N messages" do
        expect(compactor.call(keep: 3).map(&:content)).to eq(%w[third fourth fifth])
      end

      it "marks the context as compacted" do
        compactor.call(keep: 3)
        expect(ctx.compacted?).to be(true)
      end
    end

    context "when keep is a percentage string" do
      before do
        10.times { |i| add_message "user", "msg #{i}" }
      end

      it "keeps the specified percentage of messages" do
        result = compactor.call(keep: "50%")
        expect(result.size).to eq(5)
        expect(result.first.content).to eq("msg 5")
      end

      it "rounds fractional percentages" do
        result = compactor.call(keep: "33%")
        expect(result.size).to eq(3)
      end

      it "returns nil when percentage rounds to zero" do
        expect(compactor.call(keep: "0%")).to be_nil
      end
    end

    context "when keep is a string integer" do
      before do
        add_message "user", "first"
        add_message "assistant", "second"
        add_message "user", "third"
      end

      it "parses it as an integer" do
        expect(compactor.call(keep: "2").map(&:content)).to eq(%w[second third])
      end
    end

    context "when system messages are present" do
      before do
        add_message "system", "You are helpful"
        add_message "user", "first"
        add_message "assistant", "second"
        add_message "user", "third"
        add_message "assistant", "fourth"
      end

      it "preserves system messages and the last N" do
        compactor.call(keep: 2)
        expect(ctx.messages.to_a).to eq([
          LLM::Message.new("system", "You are helpful"),
          LLM::Message.new("user", "third"),
          LLM::Message.new("assistant", "fourth")
        ])
      end

      it "does not count system messages toward keep" do
        compactor.call(keep: 1)
        expect(ctx.messages.size).to eq(2)
        expect(ctx.messages.last.content).to eq("fourth")
      end
    end

    context "when there are no non-system messages" do
      before { add_message "system", "You are helpful" }

      it { expect(compactor.call).to be_nil }
    end

    context "when exactly keep non-system messages exist" do
      before do
        add_message "user", "first"
        add_message "assistant", "second"
        add_message "user", "third"
      end

      it "compacts with strict threshold" do
        expect(compactor.call(keep: 3).map(&:content)).to eq(%w[first second third])
      end
    end

    context "when tool calls span the truncation boundary" do
      before do
        add_message "user", "weather?"
        add_tool_call "get_forecast", location: "NYC"
        add_message "tool", LLM::Function::Return.new("call_1", "get_forecast", "72°F")
        add_message "assistant", "It's 72°F"
        add_message "user", "and in Chicago?"
      end

      it "keeps tool_call with its return at the boundary" do
        result = compactor.call(keep: 3)
        expect(result.count(&:tool_call?)).to eq(1)
        expect(result.count(&:tool_return?)).to eq(1)
      end

      it "preserves the tool call before its return" do
        result = compactor.call(keep: 3)
        call_idx = result.index(&:tool_call?)
        ret_idx  = result.index(&:tool_return?)
        expect(call_idx).to be < ret_idx if call_idx && ret_idx
      end
    end

    context "stream lifecycle" do
      let(:events) { [] }
      let(:stream) { ctx.params[:stream] }

      before do
        add_message "user", "first"
        add_message "assistant", "second"
        add_message "user", "third"
        add_message "assistant", "fourth"
        add_message "user", "fifth"
        allow(stream).to receive(:on_compaction) { |c| events << [:start, c] }
        allow(stream).to receive(:on_compaction_finish) { |c| events << [:finish, c] }
      end

      it "emits compaction lifecycle callbacks" do
        compactor.call(keep: 3)
        expect(events).to eq([[:start, compactor], [:finish, compactor]])
      end
    end

    context "default keep value" do
      before { 70.times { |i| add_message "user", "message #{i}" } }

      it "keeps the default number of messages" do
        result = compactor.call
        expect(result.size).to eq(64)
        expect(result.last.content).to eq("message 69")
      end

      it "returns nil when under the threshold" do
        ctx.messages.replace(ctx.messages.to_a.take(50))
        expect(compactor.call).to be_nil
      end
    end
  end
end
