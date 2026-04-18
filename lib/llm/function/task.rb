# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Task} class wraps a single concurrent function call and
  # provides a small, uniform interface across threads, fibers, and async tasks.
  class Task
    ##
    # @return [Object]
    attr_reader :task

    ##
    # @return [LLM::Function, nil]
    attr_reader :function

    ##
    # @param [Thread, Fiber, Async::Task, Ractor, LLM::Function::Ractor::Task] task
    # @param [LLM::Function, nil] function
    # @return [LLM::Function::Task]
    def initialize(task, function = nil)
      @task = task
      @function = function
    end

    ##
    # @return [Boolean]
    def alive?
      return task.alive? if task.respond_to?(:alive?)
      false
    end

    ##
    # @return [LLM::Function::Return]
    def wait
      if Thread === task
        task.value
      elsif Fiber === task
        task.resume if task.alive?
        task.value
      else
        task.wait
      end
    end
    alias_method :value, :wait
  end
end
