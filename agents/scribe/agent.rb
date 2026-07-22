#!/usr/bin/env ruby
# frozen_string_literal: true

require "llm"
require "llm/tools"

class Agent < LLM::Agent
  set :name         => "scribe",
      :description  => "a documentation engineer",
      :instructions => File.read(File.join(__dir__, "prompt.md")),
      :skills       => %w[audit.md improvements.md].map { File.join(__dir__, _1) },
      :tools        => [LLM::Tool::Git, LLM::Tool::ReadFile, LLM::Tool::Rg, LLM::Tool::SwapText],
      :tracer       => :set_tracer

  def audit!
    talk("Audit the documentation for regressions and inaccuracies")
  end

  def improvements!
    talk("Analyze documentation for gaps and improvement opportunities")
  end

  private

  def set_tracer
    LLM::Tracer::Logger.new(llm, io: $stderr)
  end
end

def main(argv)
  llm   = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
  agent = Agent.new(llm)
  case argv[0]
  when "repl"
    agent.repl(path: "contexts/scribe.json")
  when "audit"
    agent.audit!
    agent.repl(path: "contexts/scribe.json")
  when "improvements"
    agent.improvements!
    agent.repl(path: "contexts/scribe.json")
  else
    warn "agent: expected audit, improvements, or repl but got #{argv[0]}"
    exit 1
  end
end
main(ARGV)
