# frozen_string_literal: true

module LLM::Function::Async
  ##
  # Manages an {::Async::Reactor} on a background thread. Work
  # is submitted through a thread-safe queue and run inside the
  # reactor. The reactor and its fibers stay on one thread.
  class Reactor
    ##
    # @return [Thread]
    attr_reader :thread

    def initialize
      @inbox = Queue.new
      @thread = ::Thread.new { run }
    end

    ##
    # Submit a block to run inside the reactor.
    # @return [nil]
    def submit(&block)
      @inbox << block
      nil
    end

    ##
    # Stop the reactor and wait for the thread to finish.
    def stop
      @inbox << :stop
      @thread.join(5)
      @thread.kill if @thread.alive?
    end

    private

    def run
      reactor = ::Async::Reactor.new
      reactor.async do
        loop do
          work = @inbox.pop
          break if work == :stop
          reactor.async { work.call }
        end
      end
      reactor.run
    end
  end
end
