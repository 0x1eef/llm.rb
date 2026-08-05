# frozen_string_literal: true

module LLM::Function::Fiber
  ##
  # {LLM::Function::Fiber::Task LLM::Function::Fiber::Task}
  # wraps a function call in a scheduler-backed fiber for
  # cooperative concurrent execution. The fiber is created
  # lazily when {#wait} is called, not at construction time.
  #
  # Requires `Fiber.scheduler` — without one, raise early in
  # {#wait}. Interrupting a running task raises
  # {LLM::Interrupt} on the fiber, which stops it at the next
  # yield point.
  class Task < LLM::Function::Task
    ##
    # @param [LLM::Function] fn
    # @param [Hash] options
    def initialize(fn, options = {})
      super
    end

    ##
    # @return [nil]
    def spawn
      return if @guarded
      if Fiber.scheduler.nil?
        raise ArgumentError, "Fiber concurrency requires Fiber.scheduler"
      else
        @fiber = Fiber.schedule { function.call }
        nil
      end
    end

    ##
    # @return [Boolean]
    def alive?
      @fiber&.alive? || false
    end

    ##
    # @return [nil]
    def interrupt!
      @fiber&.raise(LLM::Interrupt) if @fiber&.alive?
      function.interrupt!
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # @return [LLM::Function::Return]
    def wait
      return @guarded if @guarded
      spawn unless @fiber
      @result ||= @fiber.value
    end
    alias_method :value, :wait

    ##
    # @return [Class]
    def group_class
      LLM::Function::Fiber::Group
    end
  end
end
