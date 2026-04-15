# frozen_string_literal: true

class LLM::Stream
  ##
  # A small queue for collecting streamed tool work. Values can be immediate
  # {LLM::Function::Return} objects or concurrent handles returned by
  # {LLM::Function#spawn}. Calling {#wait(strategy)} resolves queued work and
  # returns an array of {LLM::Function::Return} values.
  class Queue
    ##
    # @param [LLM::Stream] stream
    # @return [LLM::Stream::Queue]
    def initialize(stream)
      @stream = stream
      @items = []
    end

    ##
    # Enqueue a function return or spawned task.
    # @param [LLM::Function::Return, Thread, Async::Task, Fiber] item
    # @return [LLM::Stream::Queue]
    def <<(item)
      @items << item
      self
    end

    ##
    # Returns true when the queue is empty.
    # @return [Boolean]
    def empty?
      @items.empty?
    end

    ##
    # Waits for queued work to finish and returns function results.
    # @param [Symbol] strategy
    #   Controls concurrency strategy:
    #   - `:thread`: Use threads
    #   - `:task`: Use async tasks (requires async gem)
    #   - `:fiber`: Use raw fibers
    # @return [Array<LLM::Function::Return>]
    def wait(strategy)
      returns, tasks = @items.shift(@items.length).partition { LLM::Function::Return === _1 }
      results = case strategy
      when :thread then LLM::Function::ThreadGroup.new(tasks).wait
      when :task then LLM::Function::TaskGroup.new(tasks).wait
      when :fiber then LLM::Function::FiberGroup.new(tasks).wait
      else raise ArgumentError, "Unknown strategy: #{strategy.inspect}. Expected :thread, :task, or :fiber"
      end
      returns.concat fire_hooks(tasks, results)
    end
    alias_method :value, :wait

    private

    def fire_hooks(tasks, results)
      results.each_with_index do |result, idx|
        tool = tasks[idx]&.function
        @stream.on_tool_return(tool, result) if tool
      end
      results
    end
  end
end
