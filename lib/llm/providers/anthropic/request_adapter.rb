# frozen_string_literal: true

class LLM::Anthropic
  ##
  # @private
  module RequestAdapter
    require_relative "request_adapter/completion"

    ##
    # @param [Array<LLM::Message>] messages
    #  The messages to adapt
    # @return [Array<Hash>]
    def adapt(messages, mode: nil)
      messages.filter_map do
        Completion.new(_1).adapt
      end
    end

    private

    ##
    # @param [Hash] params
    # @return [Hash]
    def adapt_tools(tools)
      return {} unless tools&.any?
      {tools: tools.map { _1.respond_to?(:adapt) ? _1.adapt(self) : _1 }}
    end
  end
end
