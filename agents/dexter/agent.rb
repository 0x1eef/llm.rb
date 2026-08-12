#!/usr/bin/env ruby
# frozen_string_literal: true

require "llm"
require "llm/tools"

class Agent < LLM::Agent
  set :name         => "dexter",
      :description  => "release engineer",
      :instructions => File.read(File.join(__dir__, "prompt.md")),
      :skills       => %w[release.md].map { File.join(__dir__, _1) },
      :tools        => [LLM::Tool::Git, LLM::Tool::ReadFile, LLM::Tool::Rg, LLM::Tool::EditFile],
      :path         => File.join(__dir__, "..", "..", "contexts", "dexter.json"),
      :tracer       => :set_tracer

  def release(version:)
    talk("Let's release version #{version}!")
  end

  private

  def set_tracer
    LLM::Tracer::PrettyLogger.new(llm, io: $stderr)
  end
end

def main(argv)
  llm   = LLM.alibaba(key: ENV["ALIBABA_SECRET"])
  agent = Agent.new(llm)
  case argv[0]
  when "repl"
    agent.repl
  when "release"
    agent.release(version: ARGV[1])
    agent.repl
  else
    warn "agent: expected release, repl but got #{argv[0]}"
    exit 1
  end
end
main(ARGV)
