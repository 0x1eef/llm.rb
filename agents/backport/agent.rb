#!/usr/bin/env ruby
# frozen_string_literal: true

require "llm"
require "llm/tools/git"
require "llm/tools/read_file"
require "llm/tools/write_file"
require "llm/tools/rg"
require "llm/tools/chdir"
require "llm/tools/pwd"
require "llm/tools/swap_text"
require "llm/tools/mkdir"

class Researcher < LLM::Agent
  instructions :set_instructions
  tools :set_tools
  tracer :set_tracer
  concurrency :thread

  def run
    talk("Let's start our research")
  end

  private

  def set_instructions
    File.read File.join(__dir__, "researcher.md")
  end

  def set_tools
    [
      LLM::Tool::Git, LLM::Tool::ReadFile,
      LLM::Tool::Rg, LLM::Tool::WriteFile,
      LLM::Tool::Pwd, LLM::Tool::Chdir
    ]
  end

  def set_tracer
    LLM::Tracer::Logger.new(llm, io: $stderr)
  end
end

class Coder < LLM::Agent
  instructions :set_instructions
  tools :set_tools
  tracer :set_tracer
  concurrency :thread

  def run
    talk("Let's implement our research")
  end

  private

  def set_instructions
    File.read File.join(__dir__, "coder.md")
  end

  def set_tools
    [
      LLM::Tool::Git, LLM::Tool::ReadFile,
      LLM::Tool::WriteFile, LLM::Tool::Rg,
      LLM::Tool::Pwd, LLM::Tool::Chdir,
      LLM::Tool::SwapText, LLM::Tool::Mkdir
    ]
  end

  def set_tracer
    LLM::Tracer::Logger.new(llm, io: $stderr)
  end
end

def main(argv)
  case argv[0]
  when "research"
    llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
    agent = Researcher.new(llm).tap(&:run)
  when "code"
    llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
    agent = Coder.new(llm).tap(&:run)
  end

  4.times { puts }
  message = agent.messages.last
  puts "content: #{message.content}"
  puts "reasoning: #{message.reasoning_content}"
  puts "approx cost: $#{agent.cost}"
  puts
end
main(ARGV)
