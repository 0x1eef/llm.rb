# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Exec} class implements a tool that can
  # spawn a command. That can be dangerous given a low-quality
  # model, or a high-quality model that simply makes a bad
  # decision. The risk can be reduced through a confirmation
  # step such as {LLM::Agent.confirm LLM::Agent.confirm}, or
  # by managing the tool loop manually through
  # {LLM::Context LLM::Context}.
  class Exec < self
    require_relative "utils"
    include Utils

    name "exec"
    description "Run a command without a shell"
    parameter :name, String, "the command name"
    parameter :arguments, Array[String], "one or more command arguments"
    parameter :timeout, Integer, "the maximum allowed time for the command to run (in seconds)"
    parameter :max_chars, Integer, "max number of chars to emit"
    required %i[name]
    defaults arguments: [], timeout: 60, max_chars: :max_chars

    ##
    # @param [String] name
    #  The name of a command
    # @param [Array<String>] arguments
    #  One or more command-line arguments
    # @return [Hash]
    def call(name:, arguments: [], timeout: 60, max_chars: self.class.max_chars)
      command = spawn(name:, arguments:, max_chars:)
      wait(command:, timeout:)
      {ok: command.success?,
       stdout: truncate(command.stdout, max_chars:),
       stderr: truncate(command.stderr, max_chars:)}
    rescue LLM::Interrupt
      command.kill! if command&.running?
      raise
    end

    private

    ##
    # @param [String] name
    # @param [Array<String>] arguments
    # @param [Integer] max_chars
    # @return [Command]
    def spawn(name:, arguments:, max_chars:)
      Command
        .new(name)
        .limit(stdout: max_chars, stderr: max_chars)
        .argv(*[*arguments])
        .spawn
    end

    LLM.require "test-cmd.rb", "~> 2.5"
    Command = Test::Command
  end
end
