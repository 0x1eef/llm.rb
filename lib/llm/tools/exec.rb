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
    parameter :max_bytes, Integer, "max number of bytes to emit"
    required %i[name]
    defaults arguments: [], timeout: 60, max_bytes: :max_bytes

    ##
    # @param [String] name
    #  The name of a command
    # @param [Array<String>] arguments
    #  One or more command-line arguments
    # @return [Hash]
    def call(name:, arguments: [], timeout: 60, max_bytes: self.class.max_bytes)
      command = spawn(name:, arguments:, max_bytes:)
      wait(command:, timeout:)
      {ok: command.success?,
       stdout: truncate(command.stdout, max_bytes:),
       stderr: truncate(command.stderr, max_bytes:)}
    rescue LLM::Interrupt
      command.kill! if command&.running?
      raise
    end

    private

    ##
    # @param [String] name
    # @param [Array<String>] arguments
    # @param [Integer] max_bytes
    # @return [Command]
    def spawn(name:, arguments:, max_bytes:)
      Command
        .new(name)
        .limit(stdout: max_bytes, stderr: max_bytes)
        .argv(*[*arguments])
        .spawn
    end

    LLM.require "test-cmd.rb", "~> 2.5"
    Command = Test::Command
  end
end
