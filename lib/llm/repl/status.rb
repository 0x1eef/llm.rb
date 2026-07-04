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
    # @param [String] value
    # @return [void]
    attr_writer :text

    ##
    # @return [String]
    def to_s
      "provider: #{@provider}  status: #{@text}"
    end
  end
end
