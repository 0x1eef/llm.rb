# frozen_string_literal: true

class LLM::Registry
  ##
  # A single model from the registry, wrapping its
  # metadata (pricing, limits, capabilities, and
  # modalities).
  class Model
    ##
    # @return [LLM::Object]
    #  The model's metadata.
    attr_reader :data

    ##
    # @param [LLM::Object] data
    #  The model's metadata.
    def initialize(data)
      @data = data
    end

    ##
    # @return [String]
    def id
      data.id
    end

    ##
    # @return [String]
    def name
      data.name || id
    end

    ##
    # @return [LLM::Object]
    #  Returns the model's pricing.
    def cost
      data.cost
    end

    ##
    # @return [LLM::Object]
    #  Returns the model's limits (context window, output).
    def limit
      data.limit
    end

    ##
    # @return [LLM::Object]
    #  Returns the model's input/output modalities.
    def modalities
      data.modalities
    end

    ##
    # @return [Integer, nil]
    #  Returns the model's context window.
    def context_window
      limit&.context
    end

    ##
    # @return [Boolean]
    def tool_call?
      !!data.tool_call
    end

    ##
    # @return [Boolean]
    def reasoning?
      !!data.reasoning
    end

    ##
    # @return [Boolean]
    def structured_output?
      !!data.structured_output
    end

    ##
    # @return [Boolean]
    def open_weights?
      !!data.open_weights
    end
  end
end
