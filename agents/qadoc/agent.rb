#!/usr/bin/env ruby
# frozen_string_literal: true

require "llm"
require "llm/tools"

class Agent < LLM::Agent
  set :name         => "qadoc",
      :model        => "deepseek-v4-pro",
      :instructions => :set_instructions,
      :tools        => :set_tools,
      :tracer       => :set_tracer,
      :concurrency  => :thread

  def run
    talk("Audit the documentation for regressions and inaccuracies")
  end

  private

  def set_instructions
    File.read File.join(__dir__, "prompt.md")
  end

  def set_tools
    LLM::Tool.subclasses
  end

  def set_tracer
    LLM::Tracer::Logger.new(llm, io: $stderr)
  end
end

def main(argv)
  llm   = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
  agent = Agent.new(llm).tap(&:run)
  agent.repl(path: "contexts/qadoc.json")
end
main(ARGV)
