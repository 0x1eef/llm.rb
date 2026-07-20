# frozen_string_literal: true

module LLM::Function::Async
  ##
  # Wraps an array of {Async::Task} objects that are running
  # {LLM::Function} calls concurrently using the async gem.
  class Group < LLM::Function::Group
    ##
    # @param [Array<Async::Task>] tasks
    # @param [LLM::Function::Reactor] reactor
    def initialize(tasks, reactor)
      @tasks = tasks
      @reactor = reactor
    end

    ##
    # @return [nil]
    def spawn
      @tasks.each(&:spawn)
      nil
    end

    ##
    # @return [Boolean]
    def alive?
      @tasks.any?(&:alive?)
    end

    ##
    # @return [nil]
    def interrupt!
      @tasks.each(&:interrupt!)
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # @return [Array<LLM::Function::Return>]
    def wait
      @tasks.map(&:wait)
    ensure
      @reactor.stop
    end
    alias_method :value, :wait
  end
end
