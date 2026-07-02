#!/usr/bin/env ruby
# frozen_string_literal: true

require File.join(__dir__, "researcher")
require File.join(__dir__, "coder")

def main(argv)
  case argv[0]
  when "research"
    llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
    agent = Researcher.new(llm).tap(&:run)
  when "code"
    llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
    agent = Coder.new(llm).tap(&:run)
  else
    warn "agent: '#{argv[0]}' is not a valid action"
    exit 1
  end

  4.times { puts }
  message = agent.messages.last
  puts "content: #{message.content}"
  puts "reasoning: #{message.reasoning_content}"
  puts "approx cost: $#{agent.cost}"
  puts
end

main(ARGV)
