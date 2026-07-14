# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Ls LLM::Tool::Ls} class implements
  # a tool that can list files and directories, with an
  # optional glob pattern to filter results.
  class Ls < self
    name "ls"
    description "list files and directories, optionally matching a glob pattern"
    parameter :path, String, "the directory to list (default is cwd)"
    parameter :glob, String, "an optional glob pattern (e.g. '*.rb', '**/*.md')"

    ##
    # @param [String] path
    # @param [String, nil] glob
    # @return [Hash]
    def call(path: Dir.getwd, glob: "*")
      validate!(path:)
      entries = Dir.glob(File.join(path, glob))
      {ok: true, entries:, count: entries.size}
    end

    private

    def validate!(path:)
      raise "path does not exist: #{path}" unless Dir.exist?(path)
    end
  end
end
