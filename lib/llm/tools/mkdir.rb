# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Mkdir LLM::Tool::Mkdir} class implements
  # a tool that can create a tree of new directories.
  class Mkdir < self
    name "mkdir"
    description "create a new directory"
    parameter :path, String, "the path to the directory"

    ##
    # @param [String] path
    # @return [Hash]
    def call(path:)
      command = spawn(path:)
      {ok: command.success?, stdout: command.stdout, stderr: command.stderr}
    rescue LLM::Interrupt
      command.kill! if command&.running?
      raise
    end

    private

    def spawn(path:)
      Command
        .new("mkdir")
        .argv("-p", path)
        .spawn
    end

    LLM.require "test-cmd.rb", "~> 2.2"
    Command = Test::Command
  end
end
