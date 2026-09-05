# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Mkdir LLM::Tool::Mkdir} class implements
  # a tool that can create a tree of new directories.
  class Mkdir < self
    require_relative "exec"

    name "mkdir"
    description "Create a new directory\n" \
                "This command (mkdir) is spawned without a shell"
    parameter :path, String, "the path to the directory"
    parameter :max_chars, Integer, "max number of chars to emit"
    required %i[path]
    defaults max_chars: :max_chars

    ##
    # @param [String] path
    # @return [Hash]
    def call(path:, max_chars: self.class.max_chars)
      Exec.new.call(
        name: "mkdir",
        arguments: ["-p", path],
        max_chars:
      )
    end
  end
end
