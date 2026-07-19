# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Git LLM::Tool::Git} class implements
  # a tool that can perform a select number of git actions.
  # The actions it can perform are read-only - at least for
  # the time being.
  class Git < self
    require_relative "utils"
    include Utils

    name "git"
    description "perform an action with git"
    parameter :action, Enum["log", "diff", "commit", "checkout", "branch", "show"], "the git operation to perform"
    parameter :arguments, Array[String], "one or more arguments for the git action"
    parameter :timeout, Integer, "the maximum time to allow the command to run"
    required %i[action]
    defaults arguments: [], timeout: 5

    ##
    # @param [String] action
    # @param [Array<String>, nil] arguments
    # @return [Hash]
    def call(action:, arguments: [], timeout: 5)
      command = spawn(action:, arguments:)
      wait(command:, timeout:)
      {ok: command.success?, stdout: command.stdout, stderr: command.stderr}
    end

    private

    def spawn(action:, arguments:)
      Command
        .new("git")
        .argv(action)
        .argv(*[*arguments])
        .spawn
    end

    LLM.require "test-cmd.rb"
    Command = Test::Cmd
  end
end
