# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Git LLM::Tool::Git} class implements
  # a tool that can perform a select number of git actions.
  # The actions it can perform are read-only - at least for
  # the time being.
  class Git < self
    require_relative "utils"
    require_relative "exec"
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
      Exec.new.call(
        name: "git",
        arguments: [action, *arguments],
        timeout:
      )
    end
  end
end
