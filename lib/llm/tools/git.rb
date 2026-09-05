# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Git LLM::Tool::Git} class implements
  # a tool that can perform a select number of git actions.
  class Git < self
    require_relative "exec"

    ##
    # @return [Array<String>]
    #  The git actions that can be performed by this tool.
    def self.actions
      ["log", "diff",
       "commit", "checkout",
       "branch", "show"]
    end

    name "git"
    description "Perform an action with git\n" \
                "This command (git) is spawned without a shell"
    parameter :action, Enum[*actions], "the git operation to perform"
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
