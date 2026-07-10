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
      @rows = [[]]
      @offset = 0
    end

    ##
    # @param [String] chars
    # @return [void]
    def write(chars, attrs = nil)
      chars.each_char { write_char(_1, attrs) }
    end

    ##
    # @return [void]
    def scroll_up(height)
      max = [@rows.size - height, 0].max
      @offset = [@offset + 1, max].min
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
      last = @rows.size - 1 - @offset
      first = [last - height + 1, 0].max
      @rows[first..last] || []
    end

    private

    def write_char(char, attrs)
      if char == "\n"
        @offset += 1 if @offset > 0
        @rows.push([])
      elsif char == " " and @rows.last.length >= WIDTH
        @offset += 1 if @offset > 0
        @rows.push([])
      else
        @rows[-1].push({char:, attrs:})
      end
    end
  end
end
