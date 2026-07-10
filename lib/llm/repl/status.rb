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
    def initialize(agent)
      @agent = agent
      @provider = agent.llm.name
      @text = "idle"
    end

    ##
    # @return [Integer, nil]
    def remaining_context
      used  = @agent.usage.total_tokens
      total = @agent.context_window
      return if total.to_i <= 0
      (((total - used).to_f / total.to_f) * 100).round(2)
    end

    ##
    # @return [String]
    def cost
      "$#{@agent.cost}"
    end

    ##
    # @return [String]
    attr_accessor :text

    ##
    # @return [String]
    alias_method :to_s, :text

  end
end
