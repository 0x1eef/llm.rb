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
    parameter :max_count, Integer, "the max number of results per file"
    required %i[patterns]
    defaults path: Dir.getwd, timeout: 5, max_count: 10

    ##
    # @param [Array<String>] patterns
    # @param [String] path
    # @return [Hash]
    def call(patterns:, path: Dir.getwd, timeout: 5, max_count: 10)
      validate!(patterns:, path:, max_count:)
      command = spawn(patterns:, path:, max_count:)
      wait(command:, timeout:)
      {ok: command.success?, stdout: command.stdout, stderr: command.stderr}
    rescue LLM::Interrupt
      command.kill! if command&.running?
      raise
    end

    private

    def validate!(patterns:, path:, max_count:)
      if !(::Integer === max_count) || max_count.zero? || max_count.negative?
        raise RuntimeError, "max_count must be a positive integer"
      elsif path == "/"
        raise RuntimeError, "you can't search from the root of the filesystem"
      elsif patterns == ["."]
        raise RuntimeError, "narrow your search"
      end
    end

    def spawn(patterns:, path:, max_count:)
      Command
        .new("rg")
        .argv("-m", max_count)
        .argv(*[*patterns].flat_map { ["-e", _1] }, path)
        .spawn
    end

    LLM.require "test-cmd.rb", "~> 2.2"
    Command = Test::Command
  end
end
