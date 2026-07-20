# frozen_string_literal: true

module LLM::Function::Async
  ##
  # {LLM::Function::Async::Task LLM::Function::Async::Task}
  # wraps a function call in an {Async::Task} running on a
  # shared {LLM::Function::Async::Reactor}. The task is
  # spawned lazily in {#wait} (or explicitly in {#spawn}).
  #
  # Results are bridged from the reactor thread to the caller
  # through a {Queue}. Interrupt raises {LLM::Interrupt} on
  # the reactor fiber via `fiber.raise`, which matches the
  # pattern used by {LLM::Function::Thread::Task}.
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
    # Spawns the async task on the reactor. The function runs
    # inside the reactor thread; the result is pushed to a
    # queue that {#wait} consumes.
    # @return [nil]
    def spawn
      @queue = Queue.new
      @async = @reactor.async do
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
      @async&.alive? || false
    end

    ##
    # Raises {LLM::Interrupt} on the reactor fiber. The async
    # block catches it, unblocks the queue, and re-raises so
    # the exception propagates through the reactor.
    # @return [nil]
    def interrupt!
      @async&.fiber&.raise(LLM::Interrupt) if @async&.alive?
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # Waits for the async task to complete and returns the
    # function's return value. If the task was interrupted,
    # re-raises {LLM::Interrupt}.
    # @return [LLM::Function::Return]
    def wait
      spawn unless @async
      result = @queue.pop
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
