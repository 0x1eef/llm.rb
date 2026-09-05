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
    parameter :subcommand, Enum[*actions], "the git subcommand to run"
    parameter :arguments, Array[String], "one or more arguments forwarded to the git subcommand"
    parameter :timeout, Integer, "the maximum time to allow the command to run"
    required %i[subcommand]
    defaults arguments: [], timeout: 5

    ##
    # @param [String] subcommand
    # @param [Array<String>, nil] arguments
    # @return [Hash]
    def call(subcommand:, arguments: [], timeout: 5)
      Exec.new.call(
        name: "git",
        arguments: [subcommand, *arguments],
        timeout:
      )
    end
  end
end
