# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Git LLM::Tool::Git} class implements
  # a tool that can perform a select number of git subcommands.
  class Git < self
    require_relative "exec"

    name "git"
    description "Perform a git subcommand\n" \
                "This command (git) is spawned without a shell"
    parameter :arguments, Array[String], "one or more arguments forwarded to git"
    parameter :timeout, Integer, "the maximum time to allow the command to run (in seconds)"
    required %i[arguments]
    defaults arguments: [], timeout: 5

    ##
    # @param [String] subcommand
    # @param [Array<String>, nil] arguments
    # @return [Hash]
    def call(arguments: [], timeout: 5)
      subcommand = arguments[0]
      validate!(subcommand:, arguments:)
      Exec.new.call(
        name: "git",
        arguments: [subcommand, *arguments[1..]],
        timeout:
      )
    end

    private

    ##
    # @return [void]
    def validate!(subcommand:, arguments:)
      unless subcommands.include?(subcommand.to_s)
        raise RuntimeError, "git subcommand must be one of: #{subcommands.join(",")}"
      end
    end

    ##
    # @return [Array<String>]
    #  The git subcommands that can be performed by this tool.
    def subcommands
      ["log", "diff", "commit", "checkout", "branch", "show"]
    end
  end
end
