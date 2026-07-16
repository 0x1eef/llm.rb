#!/usr/bin/env ruby
# frozen_string_literal: true

require "llm"
require "llm/tools"

class Agent < LLM::Agent
  set :instructions => :set_instructions,
      :tools        => :set_tools,
      :tracer       => :set_tracer,
      :concurrency  => :thread

  def run(version:)
    talk("Let's prepare the #{version} release")
  end

  private

  def set_instructions
    File.read File.join(__dir__, "prompt.md")
  end

  def set_tools
    [LLM::Tool::Git, LLM::Tool::ReadFile, LLM::Tool::Rg, LLM::Tool::SwapText]
  end

  def set_tracer
    LLM::Tracer::Logger.new(llm, io: $stderr)
  end
end

def main(argv)
  version = argv[0]
  if version.nil? || version.strip.empty?
    warn "release: provide a version"
  else
    llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
    agent = Agent.new(llm).tap { _1.run(version:) }
    agent.repl
  end
end
main(ARGV)
