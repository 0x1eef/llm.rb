# frozen_string_literal: true

module LLM::OpenAI::ResponseAdapter
  module Completion
    include LLM::Completion

    ##
    # (see LLM::Completion#messages)
    def messages
      body.choices.map.with_index do |choice, index|
        choice = LLM::Object.from(choice)
        message = choice.message
        extra = {
          index:, response: self,
          logprobs: choice.logprobs,
          tool_calls: adapt_tool_calls(message.tool_calls),
          original_tool_calls: message.tool_calls
        }
        LLM::Message.new(message.role, message.content, extra)
      end
    end
    alias_method :choices, :messages

    ##
    # (see LLM::Completion#input_tokens)
    def input_tokens
      body.usage["prompt_tokens"] || 0
    end

    ##
    # (see LLM::Completion#output_tokens)
    def output_tokens
      body.usage["completion_tokens"] || 0
    end

    ##
    # (see LLM::Completion#total_tokens)
    def total_tokens
      body.usage["total_tokens"] || 0
    end

    ##
    # (see LLM::Completion#usage)
    def usage
      super
    end

    ##
    # (see LLM::Completion#model)
    def model
      body.model
    end

    private

    def adapt_tool_calls(tools)
      (tools || []).filter_map do |tool|
        next unless tool.function
        tool = {
          id: tool.id,
          name: tool.function.name,
          arguments: JSON.parse(tool.function.arguments)
        }
        LLM::Object.new(tool)
      end
    end
  end
end
