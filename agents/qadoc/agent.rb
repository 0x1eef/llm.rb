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
    talk("Run a full documentation audit")
  end

  def find_regressions
    talk("Audit the documentation for regressions and inaccuracies")
  end

  def find_improvements
    talk("Analyze documentation for gaps and improvement opportunities")
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
  agent = Agent.new(llm)
  case argv[0]
  when "find-regressions" then agent.find_regressions
  when "find-improvements" then agent.find_improvements
  else agent.run
  end
  agent.repl(path: "contexts/qadoc.json")
end
main(ARGV)
