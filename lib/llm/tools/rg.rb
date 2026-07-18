# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Rg LLM::Tool::Rg} class implements
  # a frontend to the popular 'rg' tool. The tool can
  # recursively search the current working directory
  # for one or more patterns.
  class Rg < self
    require_relative "utils"
    include Utils

    name "rg"
    description "recursively search the current directory for lines matching a pattern"
    parameter :patterns, Array[String], "one or more search patterns"
    parameter :path, String, "the path where the search is performed (default is cwd)"
    parameter :timeout, Integer, "the number of seconds to wait before cancelling the action"
    required %i[patterns]
    defaults path: Dir.getwd, timeout: 5

    ##
    # @param [Array<String>] patterns
    # @param [String] path
    # @return [Hash]
    def call(patterns:, path: Dir.getwd, timeout: 5)
      validate!(patterns:, path:)
      command = spawn(patterns:, path:)
      wait(command:, timeout:)
      {ok: command.success?, stdout: command.stdout, stderr: command.stderr}
    end

    private

    def validate!(patterns:, path:)
      if path == "/"
        raise RuntimeError, "you can't search from the root of the filesystem"
      elsif patterns == ["."]
        raise RuntimeError, "narrow your search"
      end
    end

    def spawn(patterns:, path:)
      Command.new("rg")
        .argv(*[*patterns].flat_map { ["-e", _1] }, path)
        .spawn
    end

    LLM.require "test-cmd.rb"
    Command = Test::Cmd
  end
end
