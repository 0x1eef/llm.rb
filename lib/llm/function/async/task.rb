# frozen_string_literal: true

module LLM::Function::Async
  ##
  # {LLM::Function::Async::Task} wraps a function call in an
  # {Async::Task} running on a shared
  # {LLM::Function::Async::Reactor}. The task is spawned lazily
  # in {#wait} or explicitly in {#spawn}.
  #
  # Work is submitted to the reactor through its inbox queue.
  # Results are bridged back through the task's own queue.
  class Task < LLM::Function::Task
    ##
    # @param [LLM::Function] fn
    # @param [Hash] options
    # @option options [LLM::Function::Async::Reactor] :reactor
    def initialize(fn, options = {})
      super
      @reactor = options[:reactor]
    end

    ##
    # Assign the reactor. Used when a task is created before its
    # reactor is available.
    # @param [LLM::Function::Async::Reactor] reactor
    def reactor=(reactor)
      @reactor = reactor
    end

    ##
    # Submit the function call to the reactor. The result is
    # pushed to a queue that {#wait} consumes.
    # @return [nil]
    def spawn
      return if @guarded
      @queue = Queue.new
      @alive = true
      @reactor.submit do
        @queue << function.call
      rescue LLM::Interrupt => e
        @queue << e
        raise
      end
      nil
    end

    ##
    # @return [Boolean]
    def alive?
      @alive || false
    end

    ##
    # Push an interrupt sentinel to the result queue. The reactor
    # thread continues running but the result is discarded.
    # @return [nil]
    def interrupt!
      if @queue
        @alive = false
        @queue << LLM::Interrupt.new
      end
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # Wait for the result queue to contain a value.
    # @return [LLM::Function::Return]
    def wait
      return @guarded if @guarded
      spawn unless @queue
      result = @queue.pop
      @alive = false
      raise result if LLM::Interrupt === result
      result
    end
    alias_method :value, :wait

    ##
    # @return [Class]
    def group_class
      LLM::Function::Async::Group
    end
  end
end
