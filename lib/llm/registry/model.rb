# frozen_string_literal: true

class LLM::Registry
  ##
  # A single model from the registry, wrapping its
  # metadata (pricing, limits, capabilities, and
  # modalities).
  #
  # Models are {Comparable} by price: input cost first, then
  # output cost, so `models.sort` orders them from cheapest to
  # most expensive.
  class Model
    include Comparable

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
    # @return [Float, nil]
    #  Returns the input price per million tokens, or nil when unpriced.
    def input_cost
      cost&.input
    end

    ##
    # @return [Float, nil]
    #  Returns the output price per million tokens, or nil when unpriced.
    def output_cost
      cost&.output
    end

    ##
    # Compares models by price: input cost first, then output cost.
    # Models without a price sort as the most expensive.
    # @param [LLM::Registry::Model] other
    # @return [Integer, nil]
    def <=>(other)
      [price(input_cost), price(output_cost)] <=> [price(other.input_cost), price(other.output_cost)]
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

    private

    ##
    # Maps a missing price to infinity so unpriced models sort last.
    # @param [Float, nil] value
    # @return [Float]
    def price(value)
      value.nil? ? Float::INFINITY : value.to_f
    end
  end
end
