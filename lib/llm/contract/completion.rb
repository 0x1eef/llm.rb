# frozen_string_literal: true

module LLM::Contract
  ##
  # Defines the interface all completion responses must implement
  # @abstract
  module Completion
    extend LLM::Contract

    ##
    # @return [Array<LLM::Messsage>]
    #  Returns one or more messages
    def messages
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end
    alias_method :choices, :messages

    ##
    # @return [Integer]
    #  Returns the number of input tokens
    def input_tokens
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # @return [Integer]
    #  Returns the number of output tokens
    def output_tokens
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # @return [Integer]
    #  Returns the total number of tokens
    def total_tokens
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # @return [LLM::Usage]
    #  Returns usage information
    def usage
      LLM::Usage.new(
        input_tokens:,
        output_tokens:,
        total_tokens:
      )
    end

    ##
    # @return [String]
    #  Returns the model name
    def model
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end
  end
end
