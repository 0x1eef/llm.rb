# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Bar LLM::Repl::Bar} class renders a
  # small progress bar for the REPL. It is used to show
  # the remaining size of the model's context window in
  # a compact form near the input line.
  # @api private
  class Bar
    ##
    # @return [String]
    OCCUPIED = "█"

    ##
    # @return [String]
    FREE = " "

    ##
    # @param [Integer] used
    # @param [Integer] total
    # @param [Integer] width
    # @return [LLM::Repl::Bar]
    def initialize(used:, total:, width: 10)
      @width = width
      @label, @filled = remainder(used, total)
    end

    ##
    # @return [String]
    def to_s
      bar = "#{OCCUPIED * filled}#{FREE * (width - filled)}"
      "│#{bar}│ #{label}"
    end

    private

    ##
    # @param [Integer] used
    # @param [Integer] total
    # @return [[String, Integer]]
    def remainder(used, total)
      if total <= 0
        ["???", width]
      else
        diff = (total - used).to_f
        remaining = ((diff / total.to_f) * 100).round(2)
        ["#{remaining}%", ((remaining.to_f / 100) * width).round]
      end
    end

    attr_reader :label, :filled, :width
  end
end
