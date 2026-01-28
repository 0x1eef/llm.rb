# frozen_string_literal: true

class LLM::OpenAI
  ##
  # @private
  class StreamParser
    ##
    # Returns the fully constructed response body
    # @return [Hash]
    attr_reader :body

    ##
    # @return [LLM::OpenAI::Chunk]
    def initialize(io)
      @body = {}
      @io = io
    end

    ##
    # @param [Hash] chunk
    # @return [LLM::OpenAI::Chunk]
    def parse!(chunk)
      tap { merge!(chunk) }
    end

    private

    def merge!(chunk)
      chunk.each do |key, value|
        if key == "choices"
          @body["choices"] ||= []
          merge_choices!(value)
        else
          @body[key] = value
        end
      end
    end

    def merge_choices!(choices)
      choices.each do |choice|
        index = choice["index"]
        if @body["choices"][index]
          target_message = @body["choices"][index]["message"]
          delta = choice["delta"]
          delta.each do |key, value|
            if key == "content"
              target_message[key] ||= +""
              target_message[key] << value
              @io << value if @io.respond_to?(:<<)
            elsif key == "tool_calls"
              merge_tools!(target_message, value)
            else
              target_message[key] = value
            end
          end
        else
          message_hash = {"role" => "assistant"}
          @body["choices"][index] = {"message" => message_hash}
          choice["delta"].each do |key, value|
            if key == "content"
              @io << value if @io.respond_to?(:<<)
              message_hash[key] = value
            else
              message_hash[key] = value
            end
          end
        end
      end
    end

    def merge_tools!(target, tools)
      target["tool_calls"] ||= []
      tools.each.with_index do |toola, index|
        tindex = toola["index"]
        tindex = index unless Integer === tindex && tindex >= 0
        toolb = target["tool_calls"][tindex]
        if toolb && toola["function"] && toolb["function"]
          # Append to existing function arguments
          toola["function"].each do |func_key, func_value|
            toolb["function"][func_key] ||= +""
            toolb["function"][func_key] << func_value
          end
        else
          target["tool_calls"][tindex] = toola
        end
      end
    end
  end
end
