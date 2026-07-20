# frozen_string_literal: true

module LLM::Function::Ractor
  ##
  # Wraps an array of {Ractor::Task} objects that are running
  # {LLM::Function} calls concurrently.
  class Group
    ##
    # @param [Array<LLM::Function::Task>] tasks
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
