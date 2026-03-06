#!/usr/bin/env ruby

require "llm"
require "test-cmd"

class Result < LLM::Schema
  property :success, Boolean, "Command success", required: true
end

class Shell < LLM::Tool
  name "shell"
  description "Run a shell command"
  param :command, String, "Command name", required: true
  param :arguments, Array[String], "Command arguments", required: true

  def call(command:, arguments:)
    c = cmd(command, *arguments)
    {stdout: c.stdout, stderr: c.stderr, exitstatus: c.exit_status}
  end
end

class SystemAdmin < LLM::Agent
  model "gpt-4.1"
  instructions "You are a Linux system admin"
  tools Shell
  schema Result
end

llm = LLM.openai(key: ENV["KEY"], persistent: true)
vals = ["ls", "uname", "df"].map do |command|
  Thread.new do
    res = SystemAdmin.new(llm).talk("run #{command}")
    res.content!
  end
end.map(&:value)
vals.each { puts _1 }
