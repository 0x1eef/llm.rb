# frozen_string_literal: true

class LLM::Gemini
  ##
  # @private
  module Format
    ##
    # @param [Array<LLM::Message>] messages
    #  The messages to format
    # @return [Array<Hash>]
    def format(messages)
      messages.map do
        if Hash === _1
          {role: _1[:role], parts: [format_content(_1[:content])]}
        else
          {role: _1.role, parts: [format_content(_1.content)]}
        end
      end
    end

    private

    ##
    # @param [String, LLM::File] content
    #  The content to format
    # @return [String, Hash]
    #  The formatted content
    def format_content(content)
      if LLM::File === content
        file = content
        {
          inline_data: {mime_type: file.mime_type, data: file.to_b64}
        }
      else
        {text: content}
      end
    end
  end
end
