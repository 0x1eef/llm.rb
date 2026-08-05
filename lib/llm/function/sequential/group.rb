# frozen_string_literal: true

module LLM::Function::Sequential
  ##
  # Wraps an array of {LLM::Function} objects for sequential
  # execution. Provides the same interface as concurrent group
  # wrappers so callers can flow through `spawn(strategy).wait`
  # uniformly.
  class Group < LLM::Function::Group
    ##
    # @param [Array<LLM::Function>] functions
    def initialize(functions)
      @functions = functions
      @owner = nil
    end

    ##
    # @return [nil]
    def spawn
      # no-op — execution happens in wait
      nil
    end

    ##
    # @return [Boolean]
    def alive?
      false
    end

    ##
    # @return [nil]
    def interrupt!
      @owner&.raise(LLM::Interrupt)
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # @return [Array<LLM::Function::Return>]
    def wait
      @owner = Thread.current
      ##
      # Sequential groups call functions directly (no tasks), so each
      # function's guard is checked here instead.
      @functions.map { |function| function.guard&.call(function:) || function.call }
    ensure
      @owner = nil
    end
    alias_method :value, :wait
  end
end
