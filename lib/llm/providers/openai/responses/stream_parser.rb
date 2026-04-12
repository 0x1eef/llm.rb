# frozen_string_literal: true

class LLM::OpenAI
  ##
  # @private
  class Responses::StreamParser
    ##
    # Returns the fully constructed response body
    # @return [Hash]
    attr_reader :body

    ##
    # @param [#<<, LLM::Stream] stream
    #  A stream sink that implements {#<<} or the {LLM::Stream} interface
    # @return [LLM::OpenAI::Responses::StreamParser]
    def initialize(stream)
      @body = {"output" => []}
      @stream = stream
      @emits = {tools: {}}
    end

    ##
    # @param [Hash] chunk
    # @return [LLM::OpenAI::Responses::StreamParser]
    def parse!(chunk)
      tap { handle_event(chunk) }
    end

    ##
    # Frees internal parser state used during streaming.
    # @return [void]
    def free
      @emits.clear
    end

    private

    def handle_event(chunk)
      output = @body["output"]
      case chunk["type"]
      when "response.created"
        chunk.each do |k, v|
          next if k == "type"
          @body[k] = v
        end
        @body["output"] ||= []
      when "response.in_progress", "response.completed"
        response = chunk["response"] || {}
        response.each do |k, v|
          next if k == "output" && Array === output && output.any?
          @body[k] = v
        end
        @body["output"] ||= response["output"] || []
      when "response.output_item.added"
        output_index = chunk["output_index"]
        item = chunk["item"]
        output[output_index] = item
        item["content"] ||= []
        item["summary"] ||= [] if item["type"] == "reasoning"
      when "response.content_part.added"
        output_index = chunk["output_index"]
        content_index = chunk["content_index"]
        part = chunk["part"]
        output_item = output[output_index] ||= {"content" => []}
        content = output_item["content"] ||= []
        content[content_index] = part
      when "response.reasoning_summary_text.delta"
        output_item = output[chunk["output_index"]]
        if output_item && output_item["type"] == "reasoning"
          summary_index = chunk["summary_index"] || 0
          delta = chunk["delta"]
          summary = output_item["summary"] ||= []
          if (summary_item = summary[summary_index])
            summary_item["text"] << delta
          else
            summary[summary_index] = {"type" => "summary_text", "text" => delta}
          end
          emit_reasoning_content(delta)
        end
      when "response.reasoning_summary_text.done"
        output_item = output[chunk["output_index"]]
        if output_item && output_item["type"] == "reasoning"
          summary_index = chunk["summary_index"] || 0
          output_item["summary"] ||= []
          output_item["summary"][summary_index] = {
            "type" => "summary_text",
            "text" => chunk["text"]
          }
        end
      when "response.output_text.delta"
        output_index = chunk["output_index"]
        content_index = chunk["content_index"]
        delta_text = chunk["delta"]
        output_item = output[output_index]
        if output_item && output_item["content"]
          content_part = output_item["content"][content_index]
          if content_part && content_part["type"] == "output_text"
            if (text = content_part["text"])
              text << delta_text
            else
              content_part["text"] = delta_text
            end
            emit_content(delta_text)
          end
        end
      when "response.function_call_arguments.delta"
        output_item = output[chunk["output_index"]]
        if output_item && output_item["type"] == "function_call"
          if (arguments = output_item["arguments"])
            arguments << chunk["delta"]
          else
            output_item["arguments"] = chunk["delta"]
          end
        end
      when "response.function_call_arguments.done"
        output_item = output[chunk["output_index"]]
        if output_item && output_item["type"] == "function_call"
          output_item["arguments"] = chunk["arguments"]
          emit_tool(chunk["output_index"], output_item)
        end
      when "response.output_item.done"
        output_index = chunk["output_index"]
        item = chunk["item"]
        output[output_index] = item
      when "response.content_part.done"
        output_index = chunk["output_index"]
        content_index = chunk["content_index"]
        part = chunk["part"]
        output_item = output[output_index] ||= {"content" => []}
        content = output_item["content"] ||= []
        content[content_index] = part
      end
    end

    def emit_content(value)
      if @stream.respond_to?(:on_content)
        @stream.on_content(value)
      elsif @stream.respond_to?(:<<)
        @stream << value
      end
    end

    def emit_reasoning_content(value)
      @stream.on_reasoning_content(value) if @stream.respond_to?(:on_reasoning_content)
    end

    def emit_tool(index, tool)
      return unless @stream.respond_to?(:on_tool_call)
      return if @emits[:tools][index]
      return unless tool["call_id"] && tool["name"]
      arguments = parse_arguments(tool["arguments"])
      return unless arguments
      function, error = resolve_tool(tool, arguments)
      @emits[:tools][index] = true
      @stream.on_tool_call(function, error)
    end

    def resolve_tool(tool, arguments)
      registered = LLM::Function.find_by_name(tool["name"])
      fn = (registered || LLM::Function.new(tool["name"])).dup.tap do |fn|
        fn.id = tool["call_id"]
        fn.arguments = arguments
      end
      [fn, (registered ? nil : @stream.tool_not_found(fn))]
    end

    def parse_arguments(arguments)
      return nil if arguments.to_s.empty?
      parsed = LLM.json.load(arguments)
      Hash === parsed ? parsed : nil
    rescue *LLM.json.parser_error
      nil
    end
  end
end
