# frozen_string_literal: true

require "setup"
require "llm/console"

RSpec.describe LLM::Console do
  subject(:console) do
    agent = Class.new(LLM::Agent) do
      set name: "spec"
    end.new(LLM.openai(key: "test"))
    described_class.new(agent:)
  end

  let(:queue) { console.instance_variable_get(:@queue) }
  let(:redraws) { @redraws }

  before do
    @redraws = 0
    ##
    # Keep the test off the terminal: no curses redraw, fixed width,
    # cheap markdown for the stream body.
    allow(console.window).to receive(:redraw) { @redraws += 1 }
    allow(console.buffer).to receive(:width).and_return(80)
    allow(console).to receive(:markdown).and_return([LLM::Console::Node.new("x")])
  end

  ##
  # read! drains stream chunks a few at a time so a fast model
  # cannot leave the key loop unresponsive while it re-renders
  # each queued chunk. The remaining chunks stay queued.
  describe "#read!" do
    def enqueue(*messages)
      queue << [:start]
      messages.each { |message| queue << message }
      console.send(:read!)
      queue
    end

    it "drains at most 4 stream chunks per call" do
      queue = enqueue(*Array.new(20) { |i| [:stream, "chunk #{i}"] })
      expect(queue.size).to eq(16)
    end

    it "performs at most 4 redraws with a large backlog" do
      enqueue(*Array.new(20) { |i| [:stream, "chunk #{i}"] })
      expect(redraws).to be <= 4
    end

    it "passes a :done message that arrives within the burst" do
      queue = enqueue(*Array.new(3) { |i| [:stream, "chunk #{i}"] }, [:done])
      expect(queue).to be_empty
    end

    it "defers a :done message that arrives after the burst" do
      queue = enqueue(*Array.new(5) { |i| [:stream, "chunk #{i}"] }, [:done])
      expect(queue.size).to be > 0
    end
  end
end
