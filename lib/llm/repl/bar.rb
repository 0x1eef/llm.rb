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
    # @param [Integer, nil] used
    #  The used context, or nil when it is unknown (eg after compaction).
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
    # @param [Integer, nil] used
    # @param [Integer] total
    # @return [[String, Integer]]
    def remainder(used, total)
      return ["???", width] if used.nil? || total <= 0
      diff = total - used
      return ["0%", 0] if diff <= 0
      remaining = (diff.fdiv(total) * 100).round(2)
      ["#{remaining}%", ((remaining / 100) * width).round]
    end

    attr_reader :label, :filled, :width
  end
end
