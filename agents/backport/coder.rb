# frozen_string_literal: true

require "llm"
require "llm/tools"

class Coder < LLM::Agent
  set :instructions => :set_instructions,
      :tools        => :set_tools,
      :tracer       => :set_tracer,
      :concurrency  => :thread

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
