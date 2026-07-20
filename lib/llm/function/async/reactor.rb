# frozen_string_literal: true

module LLM::Function::Async
  ##
  # Manages an {::Async::Reactor} and its background thread.
  # Created per-turn by {Array#spawn(:async)} and shut down
  # when all tasks complete.
  class Reactor
    ##
    # @return [Async::Reactor]
    attr_reader :reactor

    ##
    # @return [Thread]
    attr_reader :thread

    def initialize
      LLM.require "async" unless defined?(::Async)
      @reactor = ::Async::Reactor.new
      @thread = ::Thread.new { @reactor.run }
    end

    ##
    # Spawn a task inside the reactor.
    # @yield block to run inside the task
    # @return [Async::Task]
    def async(&)
      @reactor.async(&)
    end

    ##
    # Stop the reactor and wait for the thread to finish.
    def stop
      @reactor.stop
      @thread.join(5)
      @thread.kill if @thread.alive?
    end
  end
end
