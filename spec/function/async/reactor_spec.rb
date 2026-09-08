# frozen_string_literal: true

require "setup"
require "llm/function/async/reactor"

RSpec.describe LLM::Function::Async::Reactor do
  subject(:reactor) { described_class.new }

  after { reactor&.stop }

  describe "#thread" do
    it "is a Thread" do
      expect(reactor.thread).to be_a(Thread)
    end

    it "is alive on creation" do
      expect(reactor.thread).to be_alive
    end
  end

  describe "#submit" do
    let(:done) { Queue.new }

    before { reactor.submit { done << true } }

    it "runs the submitted block" do
      expect(done.pop(timeout: 1)).to be(true)
    end
  end

  describe "#stop" do
    let(:elapsed) do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      reactor.stop
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end

    describe "when no work is pending" do
      it "returns quickly" do
        expect(elapsed).to be < 1.0
      end

      it "stops the thread" do
        elapsed
        expect(reactor.thread).not_to be_alive
      end
    end

    describe "when a task is stuck" do
      before { reactor.submit { sleep 30 } }
      before { sleep 0.05 }

      it "returns within the join timeout" do
        expect(elapsed).to be < 6.0
      end

      it "stops the thread" do
        elapsed
        expect(reactor.thread).not_to be_alive
      end
    end

    describe "when a stuck task has an ensure block" do
      let(:ensured) { Queue.new }

      before do
        reactor.submit do
          sleep 30
        ensure
          ensured << true
        end
        sleep 0.05
        reactor.stop
      end

      it "runs the task's ensure block" do
        expect(ensured).not_to be_empty
      end
    end
  end
end
