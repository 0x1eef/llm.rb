module LLM
  ##
  # The {LLM::Contract LLM::Contract} module is included by contracts
  # such as {LLM::Contract::Completion}, and ensures that any module
  # including {LLM::Contract::Completion} implements all methods defined
  # by the that module.
  module Contract
    ContractError = Class.new(LLM::Error)

    ##
    # @api private
    def included(mod)
      meths = mod.instance_methods(false)
      if meths.empty?
        raise ContractError, "#{mod} does not implement any methods required by #{self}"
      else
        missing = instance_methods - meths
        if missing.any?
          raise ContractError, "#{mod} does not implement methods (#{missing.join(', ')}) required by #{self}"
        end
      end
    end
  end
end
