# frozen_string_literal: true

class LLM::Repl::Input
  ##
  # A single editable character of the input.
  class Char
    ##
    # @param [String] char
    # @return [LLM::Repl::Input::Char]
    def initialize(char)
      @char = char
    end

    ##
    # @return [String]
    def to_s
      @char
    end
  end
end
