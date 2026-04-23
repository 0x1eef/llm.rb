# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Ractor::Task} class wraps a ractor-backed function
  # call and delegates mailbox coordination to
  # {LLM::Function::Ractor::Mailbox}.
  class Ractor::Task
    ##
    # @return [LLM::Function::Ractor::Mailbox]
    attr_reader :mailbox

    ##
    # @param [Class] runner_class
    # @param [String, nil] id
    # @param [String] name
    # @param [Hash, Array, nil] arguments
    # @return [LLM::Function::Ractor::Task]
    def initialize(runner_class, id, name, arguments)
      @mailbox = Ractor::Mailbox.new(build_task(runner_class, id, name, arguments))
    end

    ##
    # @return [Boolean]
    def alive?
      mailbox.alive?
    end

    ##
    # @return [nil]
    def interrupt!
      nil
    end

    ##
    # @return [LLM::Function::Return]
    def wait
      id, name, value = mailbox.wait
      Return.new(id, name, value)
    end
    alias_method :value, :wait

    private

    def build_task(runner_class, id, name, arguments)
      ::Ractor.new(runner_class, id, name, arguments) do |runner_class, id, name, arguments|
        LLM::Function::Ractor::Job.new(::Ractor.current, runner_class, id, name, arguments).call
      end
    end
  end
end
