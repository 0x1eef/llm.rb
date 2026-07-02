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
