#!/usr/bin/env ruby
# frozen_string_literal: true

require File.join(__dir__, "researcher")
require File.join(__dir__, "coder")

def main(argv)
  case argv[0]
  when "research", "license"
    llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
    agent = Researcher.new(llm).tap(&argv[0].to_sym)
  when "code"
    llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
    agent = Coder.new(llm).tap(&:run)
  else
    warn "agent: '#{argv[0]}' is not a valid action"
    exit 1
  end
  agent.tracer = nil
  agent.repl
end

main(ARGV)
