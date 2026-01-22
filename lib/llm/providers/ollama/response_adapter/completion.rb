# frozen_string_literal: true

module LLM::Ollama::ResponseAdapter
  module Completion
    include LLM::Completion

    ##
    # (see LLM::Completion#messages)
    def messages
      adapt_choices
    end
    alias_method :choices, :messages

    ##
    # (see LLM::Completion#input_tokens)
    def input_tokens
      body.prompt_eval_count || 0
    end

    ##
    # (see LLM::Completion#output_tokens)
    def output_tokens
      body.eval_count || 0
    end

    ##
    # (see LLM::Completion#total_tokens)
    def total_tokens
      input_tokens + output_tokens
    end

    ##
    # (see LLM::Completion#model)
    def model
      body.model
    end

    private

    def adapt_choices
      message = body.message
      role, content, calls = message.role, message.content, message.tool_calls
      extra = {response: self, tool_calls: adapt_tool_calls(calls)}
      [LLM::Message.new(role, content, extra)]
    end

    def adapt_tool_calls(tools)
      return [] unless tools
      tools.filter_map do |tool|
        next unless tool["function"]
        tool["function"]
      end
    end
  end
end
