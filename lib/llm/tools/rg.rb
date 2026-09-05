# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Rg LLM::Tool::Rg} class implements
  # a frontend to the popular 'rg' tool. The tool can
  # recursively search the current working directory
  # for one or more patterns.
  class Rg < self
    require_relative "shell"

    name "rg"
    description "recursively search the current directory for lines matching a pattern"
    parameter :patterns, Array[String], "one or more search patterns"
    parameter :path, String, "the path where the search is performed (default is cwd)"
    parameter :timeout, Integer, "the number of seconds to wait before cancelling the action"
    parameter :max_count, Integer, "the max number of results per file"
    parameter :max_chars, Integer, "the max number of characters to return"
    required %i[patterns]
    defaults path: Dir.getwd, timeout: 5, max_count: 10, max_chars: :max_chars

    ##
    # @param [Array<String>] patterns
    # @param [String] path
    # @param [Integer] timeout
    # @param [Integer] max_count
    # @param [Integer] max_chars
    # @return [Hash]
    def call(patterns:, path: Dir.getwd, timeout: 5, max_count: 10, max_chars: self.class.max_chars)
      validate!(patterns:, path:, max_count:)
      Shell.new.call(
        name: "rg",
        arguments: ["-m", max_count.to_s, *[*patterns].flat_map { ["-e", _1] }, path],
        timeout:,
        max_chars:
      )
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
  end
end
