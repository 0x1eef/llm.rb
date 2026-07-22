#!/usr/bin/env ruby
# frozen_string_literal: true

require "llm"
require "llm/tools"

class Agent < LLM::Agent
  set :name         => "dexter",
      :description  => "release engineer",
      :instructions => File.read(File.join(__dir__, "prompt.md")),
      :skills       => %w[changelog.md release.md].map { File.join(__dir__, _1) },
      :tools        => [LLM::Tool::Git, LLM::Tool::ReadFile, LLM::Tool::Rg, LLM::Tool::SwapText],
      :tracer       => :set_tracer

  def changelog!
    talk("Let's update the changelog")
  end

  def release(version:)
    talk("Let's release version #{version}!")
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
    agent.repl(path: "contexts/dexter.json")
  when "changelog"
    agent.changelog!
    agent.repl(path: "contexts/dexter.json")
  when "release"
    agent.release!(version: ARGV[1])
    agent.repl(path: "contexts/dexter.json")
  else
    warn "agent: expected changelog, release but got #{argv[0]}"
    exit 1
  end
end
main(ARGV)
