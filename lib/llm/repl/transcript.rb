# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Transcript LLM::Repl::Transcript} class
  # stores streamed output for the REPL.
  # @api private
  class Transcript
    WIDTH = 80

    ##
    # @return [LLM::Repl::Transcript]
    def initialize
      @lines = [+""]
      @offset = 0
    end

    ##
    # @param [String] chars
    # @return [void]
    def write(chars)
      chars.each_char { write_char(_1) }
    end

    ##
    # @return [void]
    def scroll_up
      @offset = [@offset + 1, @lines.size - 1].min
    end

    ##
    # @return [void]
    def scroll_down
      @offset = [@offset - 1, 0].max
    end

    ##
    # @param [Integer] height
    # @return [Array<String>]
    def visible(height)
      last = @lines.size - 1 - @offset
      first = [last - height + 1, 0].max
      @lines[first..last] || []
    end

    private

    def write_char(char)
      if char == "\n"
        @lines << +""
      elsif char == " " and @lines.last.length >= WIDTH
        @lines << +""
      else
        @lines.last << char
      end
    end
  end
end
