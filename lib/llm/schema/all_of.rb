# frozen_string_literal: true

class LLM::Schema
  ##
  # The {LLM::Schema::AllOf LLM::Schema::AllOf} class represents an
  # allOf union in a JSON schema. It is a subclass of
  # {LLM::Schema::Leaf LLM::Schema::Leaf}.
  class AllOf < Leaf
    ##
    # @param [Array<LLM::Schema::Leaf>] values
    #  The values required by the union
    # @return [LLM::Schema::AllOf]
    def initialize(values)
      @values = values
    end

    ##
    # @return [Hash]
    def to_h
      super.merge!(allOf: @values)
    end
  end
end
