# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Ruby LLM::Tool::Ruby} class implements
  # a tool that can execute an arbitrary string of Ruby code
  # and return the result. It routes through {LLM::Tool::Shell}
  # for process management.
  class Ruby < self
    require "rbconfig"
    require_relative "shell"

    name "ruby"
    description "runs a string of ruby code"
    parameter :code, String, "a string of ruby code"
    parameter :timeout, Integer, "maximum runtime before timeout"
    parameter :max_chars, Integer, "max number of chars to emit"
    required %i[code]
    defaults timeout: 15, max_chars: :max_chars

    ##
    # @param [String] code
    #  Ruby code
    # @param [Integer] timeout
    #  Runtime timeout
    # @param [Integer] max_chars
    #  Max chars to emit
    # @return [Hash]
    def call(code:, timeout: 15, max_chars: self.class.max_chars)
      Shell.new.call(
        name: RbConfig.ruby,
        arguments: ["-e", code],
        timeout:,
        max_chars:
      )
    end
  end
end