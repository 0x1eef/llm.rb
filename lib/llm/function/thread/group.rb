# frozen_string_literal: true

module LLM::Function::Thread
  ##
  # Wraps an array of {Thread::Task} objects for concurrent
  # thread-based execution. Interrupts all tasks and waits
  # for them to complete.
  class Group < LLM::Function::Group
    ##
    # @param [Array<LLM::Function::Thread::Task>] tasks
    def initialize(tasks)
      @tasks = tasks
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
    end
    alias_method :value, :wait
  end
end
