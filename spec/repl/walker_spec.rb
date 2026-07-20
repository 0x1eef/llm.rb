# frozen_string_literal: true

require "setup"
require "llm/repl"

RSpec.describe LLM::Repl::Walker do
  let(:messages) do
    [
      LLM::Message.new("user", "first"),
      LLM::Message.new("assistant", "response one"),
      LLM::Message.new("user", "second"),
      LLM::Message.new("assistant", "response two"),
      LLM::Message.new("user", "third")
    ]
  end

  subject(:walker) { described_class.new(messages.select(&:user?).map(&:content)) }

  describe "#next" do
    context "when at the end" do
      it "returns nil" do
        expect(walker.next).to be_nil
      end
    end

    context "when not at the last message" do
      before { 2.times { walker.prev } }

      it "advances forward" do
        expect(walker.next).to eq("third")
      end
    end
  end

  describe "#prev" do
    context "when at the first message" do
      before { 3.times { walker.prev } }

      it "stays at the first message" do
        expect(walker.prev).to eq("first")
      end
    end

    context "when not at the first message" do
      before { walker.prev }

      it "moves backward" do
        expect(walker.prev).to eq("second")
      end
    end
  end

  describe "iteration order" do
    before { 3.times { walker.prev } }

    it "cycles through messages in reverse order" do
      expect(walker.next).to eq("second")
      expect(walker.next).to eq("third")
      expect(walker.next).to eq("third")
    end

    it "cycles through messages in forward order after going back" do
      expect(walker.next).to eq("second")
      expect(walker.prev).to eq("first")
      expect(walker.next).to eq("second")
    end
  end

  describe "empty walker" do
    let(:messages) { [] }

    it "returns nil on next" do
      expect(walker.next).to be_nil
    end

    it "returns nil on prev" do
      expect(walker.prev).to be_nil
    end
  end

  describe "single message" do
    let(:messages) { [LLM::Message.new("user", "only")] }

    it "returns nil on next" do
      expect(walker.next).to be_nil
    end

    it "returns the message on prev" do
      expect(walker.prev).to eq("only")
    end
  end
end
