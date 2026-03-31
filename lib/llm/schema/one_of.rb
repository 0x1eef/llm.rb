# frozen_string_literal: true

class LLM::Schema
  ##
  # The {LLM::Schema::OneOf LLM::Schema::OneOf} class represents an
  # oneOf union in a JSON schema. It is a subclass of
  # {LLM::Schema::Leaf LLM::Schema::Leaf}.
  class OneOf < Leaf
    ##
    # @param [Array<LLM::Schema::Leaf>] values
    #  The values allowed by the union
    # @return [LLM::Schema::OneOf]
    def initialize(values)
      @values = values
    end

    ##
    # @return [Hash]
    def to_h
      super.merge!(oneOf: @values)
    end
  end
end
