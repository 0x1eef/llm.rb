# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Status LLM::Repl::Status} class stores
  # the small status line shown at the top of the REPL.
  # @api private
  class Status
    ##
    # @param [String, Symbol] provider
    # @return [LLM::Repl::Status]
    def initialize(provider)
      @provider = provider
      @text = "idle"
    end

    ##
    # @return [String]
    attr_reader :provider

    ##
    # @return [String]
    attr_accessor :text

    ##
    # @return [String]
    alias_method :to_s, :text
  end
end
