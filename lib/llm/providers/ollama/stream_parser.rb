# frozen_string_literal: true

class LLM::Ollama
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
        if key == "message"
          if @body[key]
            @body[key]["content"] << value["content"]
            @io << value["content"] if @io.respond_to?(:<<)
          else
            @body[key] = value
            @io << value["content"] if @io.respond_to?(:<<)
          end
        else
          @body[key] = value
        end
      end
    end
  end
end
