# frozen_string_literal: true

module LLM::OpenAI::ResponseAdapter
  module Responds
    def model = body.model
    def response_id = respond_to?(:response) ? response["id"] : id
    def choices = [adapt_message]
    def annotations = choices[0].annotations

    def prompt_tokens = body.usage&.input_tokens
    def completion_tokens = body.usage&.output_tokens
    def total_tokens = body.usage&.total_tokens

    ##
    # Returns the aggregated text content from the response outputs.
    # @return [String]
    def output_text
      choices.find(&:assistant?).content || ""
    end

    private

    def adapt_message
      message = LLM::Message.new("assistant", +"", {response: self, tool_calls: []})
      output.each.with_index do |choice, index|
        if choice.type == "function_call"
          message.extra[:tool_calls] << adapt_tool(choice)
        elsif choice.content
          choice.content.each do |c|
            next unless c["type"] == "output_text"
            message.content << c["text"] << "\n"
            next unless c["annotations"]
            message.extra["annotations"] = [*message.extra["annotations"], *c["annotations"]]
          end
        end
      end
      message
    end

    def adapt_tool(tool)
      {id: tool.call_id, name: tool.name, arguments: LLM.json.load(tool.arguments)}
    end
  end
end
