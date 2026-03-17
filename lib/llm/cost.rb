# frozen_string_literal: true

##
# The {LLM::Cost LLM::Cost} class computes approximate request costs
# using pricing data from {LLM::Registry LLM::Registry}. It converts
# provider model prices from per-million-token rates into estimated
# input and output costs for a given usage object.
class LLM::Cost
  ##
  # @param [LLM::Provider] llm
  #  A subclass of LLM::Provider
  # @return [LLM::Cost]
  def initialize(llm)
    @registry = LLM.registry_for(llm)
  end

  ##
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm)
  #   ses.talk "Hello world"
  #   ses.cost.to_s # => "0.000096"
  # @param [String] model
  #  The name of a model
  # @param [LLM::Usage] usage
  #  A usage object
  # @return [LLM::Estimate]
  #  Returns an approximate cost estimate for the given model usage
  def compute(model:, usage:)
    cost = @registry.cost(model:)
    LLM::Estimate.new(
      (cost.input.to_f / 1_000_000.0)  * usage.input_tokens,
      (cost.output.to_f / 1_000_000.0) * usage.output_tokens
    )
  end
end
