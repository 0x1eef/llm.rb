# frozen_string_literal: true

module LLM
  ##
  # @api private
  #
  # The `LLM::Contract` module enforces API contracts between
  # provider response adapters and the runtime. Users never
  # interact with this module directly.
  module Contract
    ContractError = Class.new(LLM::Error)
    require_relative "contract/completion"

    ##
    # @api private
    def included(mod)
      meths = mod.instance_methods(false)
      if meths.empty?
        raise ContractError, "#{mod} does not implement any methods required by #{self}"
      end
      missing = instance_methods - meths
      if missing.any?
        raise ContractError, "#{mod} does not implement methods (#{missing.join(", ")}) required by #{self}"
      end
    end
  end
end
