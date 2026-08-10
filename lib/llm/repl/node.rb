# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Node LLM::Repl::Node} class wraps a piece
  # of text and optional curses attributes.
  # @api private
  class Node
    ##
    # @return [String]
    attr_reader :text

    ##
    # @return [Integer, nil]
    attr_reader :attrs

    ##
    # @param [String] text
    # @param [Integer, nil] attrs
    # @return [LLM::Repl::Node]
    def initialize(text, attrs = nil)
      @text = text.to_s
      @attrs = attrs
    end

    ##
    # @return [Integer]
    def size
      @text.size
    end
    alias_method :length, :size

    ##
    # Hash-like lookup.
    # @param [Symbol] key
    # @return [String, Integer, nil]
    def [](key)
      case key
      when :text then @text
      when :attrs then @attrs
      end
    end
  end
end
