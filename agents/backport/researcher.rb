# frozen_string_literal: true

require "llm"
require "llm/tools"

class Researcher < LLM::Agent
  set :instructions => :set_instructions,
      :tools        => :set_tools,
      :tracer       => :set_tracer,
      :concurrency  => :thread

  def license
    talk [
      "Let's research the recent license change.",
      "Let's make the research actionable.",
      "llm.rb and mruby-llm must have the same license",
      "The llm.rb license is the preferred license"
    ]
  end

  def research
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
