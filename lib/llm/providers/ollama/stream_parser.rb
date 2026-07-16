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
    # @param [LLM::Stream] stream
    # @return [LLM::Ollama::StreamParser]
    def initialize(stream)
      @body = {}
      @stream = stream
    end

    ##
    # @param [Hash] chunk
    # @return [LLM::OpenAI::Chunk]
    def parse!(chunk)
      tap { merge!(chunk) }
    end

    ##
    # Frees internal parser state used during streaming.
    # @return [void]
    def free
    end

    private

    def merge!(chunk)
      chunk.each do |key, value|
        if key == "message"
          if @body[key]
            @body[key]["content"] << value["content"]
            @stream.on_content(value["content"])
          else
            @body[key] = value
            @stream.on_content(value["content"])
          end
        else
          @body[key] = value
        end
      end
    end
  end
end
