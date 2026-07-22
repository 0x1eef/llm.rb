# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Ruby LLM::Tool::Ruby} class implements
  # a tool that can execute an arbitrary string of Ruby code
  # and return the result. It uses `test-cmd.rb` under the
  # hood for process management.
  class Ruby < self
    require_relative "utils"
    include Utils

    name "ruby"
    description "runs a string of ruby code"
    parameter :code, String, "a string of ruby code"
    parameter :timeout, Integer, "maximum runtime before timeout"
    required %i[code]
    defaults timeout: 15

    ##
    # @param [String] code
    #  Ruby code
    # @param [Integer] timeout
    #  Runtime timeout
    def call(code:, timeout: 15)
      command = spawn(code:)
      wait(command:, timeout:)
      {ok: command.success?, stdout: command.stdout, stderr: command.stderr}
    rescue LLM::Interrupt
      command.kill! if command&.running?
    end

    private

    def spawn(code:)
      Command
        .new(RbConfig.ruby)
        .argv("-e", code)
    end

    require "rbconfig"
    LLM.require "test-cmd.rb", "~> 1.1"
    Command = Test::Cmd
  end
end