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
    def initialize(repl)
      @repl = repl
    end

    ##
    # @param [String] chars
    #  One or more chars
    # @return [void]
    def on_content(chars)
      @repl.write(chars)
    end

    ##
    # @param [LLM::Function] tool
    # @param [LLM::Function::Return, nil] error
    # @return [void]
    def on_tool_call(tool, error)
      if error
        @repl.status = "tool error: #{tool.name}"
      else
        @repl.status = "tool: #{tool.name}"
      end
    end

    ##
    # @param [LLM::Function] _tool
    # @param [LLM::Function::Return] result
    # @return [void]
    def on_tool_return(_tool, result)
      @repl.status = "tool done: #{result.name}"
    end
  end
end
