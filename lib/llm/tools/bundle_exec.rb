# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::BundleExec} class implements
  # a tool that runs a command through `bundle exec`.
  # It inherits the `BUNDLE_GEMFILE` environment
  # variable when set, or defaults to a `Gemfile`
  # in the current working directory.
  class BundleExec < self
    require_relative "exec"

    name "bundle-exec"
    description "Run a command through bundle exec\n" \
                "This command (bundle exec) is spawned without a shell"
    parameter :name, String, "the command name"
    parameter :arguments, Array[String], "one or more command arguments"
    parameter :timeout, Integer, "the maximum allowed time for the command to run (in seconds)"
    parameter :max_bytes, Integer, "max number of bytes to emit"
    required %i[name]
    defaults arguments: [], timeout: 60, max_bytes: -> { Exec.max_bytes }

    ##
    # @return [LLM::Tool::BundleExec]
    def initialize
      @env = {"BUNDLE_GEMFILE" => ENV["BUNDLE_GEMFILE"] || File.join(Dir.getwd, "Gemfile")}
    end

    ##
    # @param [String] name
    #  The name of a command
    # @param [Array<String>] arguments
    #  One or more command-line arguments
    # @param [Integer] timeout
    #  The maximum allowed time for the command to run (in seconds)
    # @param [Integer] max_bytes
    #  Max number of bytes to emit
    # @return [Hash]
    def call(name:, arguments: [], timeout: 60, max_bytes: Exec.max_bytes)
      Exec.new(env:).call(
        name: "bundle",
        arguments: ["exec", name, *arguments],
        timeout:,
        max_bytes:
      )
    end

    private

    ##
    # Returns the `Gemfile` used by this tool:
    # the `BUNDLE_GEMFILE` environment variable
    #  when set, otherwise a `Gemfile` in the
    # current working directory.
    # @return [Hash{String => String}]
    attr_reader :env
  end
end
