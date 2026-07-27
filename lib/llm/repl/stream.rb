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
    # @return [void]
    def on_tool_call(tool)
      @_queue.push [:status, "#{tool.name}(#{format_args(tool)})"]
    end

    ##
    # @param [LLM::Function] _tool
    # @param [LLM::Function::Return] result
    # @return [void]
    def on_tool_return(_tool, result)
      @_queue.push [:status, @repl.thinking_text]
    end

    ##
    # Clear the accumulated buffer
    # @return [void]
    def clear
      @buffer.clear
    end

    private

    ##
    # Formats tool arguments as compact key: value pairs
    # suitable for the status line.  Strings are quoted and
    # truncated, arrays show their first two elements, and
    # hashes collapse to `{…}`.  The whole string is capped
    # so it fits alongside the context-usage bar.
    # @param [LLM::Function] tool
    # @param [Integer] max
    # @return [String]
    def format_args(tool, max: 50)
      ##
      # 'tool.arguments' might be returned
      # (by the model) in a different order
      # than the tool definition - this code
      # handles re-sorting.
      args   = tool.arguments
      props  = tool.params.properties.keys
      props  = props.sort_by { tool.params.properties[_1].index }
      props  = props.filter_map { args[_1] ? "#{_1}: #{format_value(args[_1])}" : nil }
      result = props.join(", ")
      result.size > max ? "#{result[0...max - 1]}…" : result
    end

    ##
    # @param [Object] value
    # @param [Integer] max
    # @return [String]
    def format_value(value, max: 18)
      case value
      when String
        value.size > max ? "#{value[0...max]}…".inspect : value.inspect
      when Array
        items = value.take(2).map { format_value(_1, max: 10) }
        items << "…" if value.size > 2
        "[#{items.join(", ")}]"
      when Hash
        "{…}"
      when nil
        "nil"
      else
        str = value.inspect
        str.size > max ? "#{str[0...max]}…" : str
      end
    end
  end
end
