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
    # Returns (or sets) the advisory maximum number of bytes
    # this tool returns to the model.
    # @param [Integer, nil] bytes
    #  When given, sets the maximum
    # @return [Integer]
    def self.max_bytes(bytes = UNDEFINED)
      if bytes.equal?(UNDEFINED)
        @max_bytes || 75_000
      else
        @max_bytes = bytes
      end
    end

    ##
    # @param [Hash] env
    #  Extra environment variables to set for the command.
    #  This is configuration for the tool instance, not a
    #  model-provided parameter.
    # @return [LLM::Tool::Exec]
    def initialize(env: {})
      @env = env
    end

    ##
    # @param [String] name
    #  The name of a command
    # @param [Array<String>] arguments
    #  One or more command-line arguments
    # @param [Integer] timeout
    #  The maximum allowed time for the command to run (in seconds)
    # @param [Integer] max_bytes
    #  the max number of bytes to emit
    # @return [Hash]
    def call(name:, arguments: [], timeout: 60, max_bytes: self.class.max_bytes)
      command = spawn(name:, arguments:, env:, max_bytes:)
      wait(command:, timeout:)
      if command.not_found?
        {ok: false, error: "command '#{name}' was not found on this system"}
      else
        {ok: command.success?,
        stdout: truncate(command.stdout, max_bytes:),
        stderr: truncate(command.stderr, max_bytes:)}
      end
    rescue LLM::Interrupt
      command.kill! if command&.running?
      raise
    end

    private

    attr_reader :env
  end
end
