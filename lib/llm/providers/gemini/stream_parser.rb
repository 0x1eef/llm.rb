# frozen_string_literal: true

class LLM::Gemini
  ##
  # @private
  class StreamParser
    ##
    # Returns the fully constructed response body
    # @return [Hash]
    attr_reader :body

    ##
    # @param [#<<] io An IO-like object
    # @return [LLM::Gemini::StreamParser]
    def initialize(io)
      @body = {"candidates" => []}
      @io = io
    end

    ##
    # @param [Hash] chunk
    # @return [LLM::Gemini::StreamParser]
    def parse!(chunk)
      tap { merge_chunk!(chunk) }
    end

    private

    def merge_chunk!(chunk)
      chunk.each do |key, value|
        k = key.to_s
        if k == "candidates"
          merge_candidates!(value)
        elsif k == "usageMetadata" &&
            @body["usageMetadata"].is_a?(Hash) &&
            value.is_a?(Hash)
          @body["usageMetadata"] = @body["usageMetadata"].merge(value)
        else
          @body[k] = value
        end
      end
    end

    def merge_candidates!(deltas)
      deltas.each do |delta|
        index = delta["index"]
        @body["candidates"][index] ||= {"content" => {"parts" => []}}
        candidate = @body["candidates"][index]
        delta.each do |key, value|
          k = key.to_s
          if k == "content"
            merge_candidate_content!(candidate["content"], value) if value
          else
            candidate[k] = value # Overwrite other fields
          end
        end
      end
    end

    def merge_candidate_content!(content, delta)
      delta.each do |key, value|
        k = key.to_s
        if k == "parts"
          content["parts"] ||= []
          merge_content_parts!(content["parts"], value) if value
        else
          content[k] = value
        end
      end
    end

    def merge_content_parts!(parts, deltas)
      deltas.each do |delta|
        if delta["text"]
          merge_text!(parts, delta)
        elsif delta["functionCall"]
          merge_function_call!(parts, delta)
        elsif delta["inlineData"]
          parts << delta
        elsif delta["functionResponse"]
          parts << delta
        elsif delta["fileData"]
          parts << delta
        end
      end
    end

    def merge_text!(parts, delta)
      last_existing_part = parts.last
      text = delta["text"]
      if last_existing_part.is_a?(Hash) && last_existing_part["text"]
        last_existing_part["text"] ||= +""
        last_existing_part["text"] << text
        @io << text if @io.respond_to?(:<<)
      else
        parts << delta
        @io << text if @io.respond_to?(:<<)
      end
    end

    def merge_function_call!(parts, delta)
      last_existing_part = parts.last
      last_call = last_existing_part.is_a?(Hash) ? last_existing_part["functionCall"] : nil
      delta_call = delta["functionCall"]
      if last_call.is_a?(Hash) && delta_call.is_a?(Hash)
        last_existing_part["functionCall"] = last_call.merge(delta_call)
        delta.each do |key, value|
          next if key == "functionCall"
          last_existing_part[key] = value
        end
      else
        parts << delta
      end
    end
  end
end
