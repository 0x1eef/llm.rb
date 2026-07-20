# frozen_string_literal: true

class LLM::Function
  ##
  # This class is the superclass that all concurrency
  # strategies must subclass in order to implement their
  # own Task class. It provides a common interface that
  # is the same across all concurrency strategies.
  class Task
    ##
    # @return [LLM::Function]
    attr_reader :function

    ##
    # @param [LLM::Function] fn
    # @param [Hash] options
    #  An optional set of options that are specific
    #  to a given concurrency strategy.
    def initialize(fn, options = {})
      @function = fn
    end

    ##
    # @abstract
    # @return [Boolean]
    def alive?
      raise NotImplementedError
    end

    ##
    # @abstract
    # @return [nil]
    def interrupt!
      raise NotImplementedError
    end
    alias_method :cancel!, :interrupt!

    ##
    # @abstract
    # @return [LLM::Function::Return]
    def wait
      raise NotImplementedError
    end
    alias_method :value, :wait

    ##
    # @abstract
    # @return [Class]
    def group_class
      raise NotImplementedError
    end
  end
end
