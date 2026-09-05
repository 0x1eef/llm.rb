# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::ReadFile LLM::Tool::ReadFile} class implements
  # a tool that can read the contents of a file. The tool accepts
  # two optional offsets: a start line, and a stop line. Without
  # either the entire file contents are read into memory.
  class ReadFile < self
    require_relative "utils"
    include Utils

    name "read-file"
    description "read the contents of a file"
    parameter :path, String, "the path to the file"
    parameter :start, Integer, "start line number"
    parameter :stop, Integer, "stop line number"
    parameter :max_chars, Integer, "the max number of characters to return"
    required %i[path]

    ##
    # @param [String] path
    # @param [Integer] start
    # @param [Integer] stop
    # @param [Integer] max_chars
    # @return [Hash]
    def call(path:, start: 1, stop: -1, max_chars: self.class.max_chars)
      ##
      # When start is greater than stop, swap them so the
      # range reads in the right direction (e.g. start: 10,
      # stop: 5 => reads lines 5-10).
      start, stop = stop, start if stop != -1 && start > stop
      content, cursor = nil, 1
      File.open(path, "r") do |f|
        while cursor < start
          f.gets
          cursor += 1
        end
        if stop == -1
          content = f.read
        else
          content = start.upto(stop).map { f.gets }.join
        end
      end
      {ok: true, content: truncate(content, max_chars:)}
    end
  end
end
