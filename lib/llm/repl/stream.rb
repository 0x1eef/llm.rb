# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Stream LLM::Repl::Stream} class manages
  # the stream for the {LLM::Repl LLM::Repl} class. This class
  # has defined hooks that receive text, tool calls, and
  # tool returns.
  # @api private
  class Stream < LLM::Stream
    ##
    # @param [LLM::Repl] repl
    # @return [LLM::Repl::Stream]
    def initialize(repl, queue)
      @repl = repl
      @_queue = queue
      @buffer = +""
    end

    ##
    # @param [String] chars
    #  One or more chars
    # @return [void]
    def on_content(chars)
      @buffer << chars
      @_queue.push [:stream, @buffer]
    end

    ##
    # @param [LLM::Function] tool
    # @param [LLM::Function::Return, nil] error
    # @return [void]
    def on_tool_call(tool, error)
      if error
        @_queue.push [:status, "tool not found: #{tool.name}"]
      else
        @_queue.push [:status, "tool: #{tool.name}"]
      end
    end

    ##
    # @param [LLM::Function] _tool
    # @param [LLM::Function::Return] result
    # @return [void]
    def on_tool_return(_tool, result)
      @_queue.push [:status, "tool done: #{result.name}"]
    end

    ##
    # Empty the accumulated buffer
    # @return [void]
    def empty!
      @buffer.clear
    end
  end
end
