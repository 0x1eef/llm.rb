# frozen_string_literal: true

require_relative "setup"
require "tmpdir"

RSpec.describe LLM::Skill do
  class WeatherTool < LLM::Tool
    name "weather"
    description "Get the current weather"

    def call(**)
      {content: "sunny"}
    end
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  before do
    LLM::Tool.clear_registry!
    LLM::Tool.register(WeatherTool)
  end

  let(:skill_dir) { File.join(@dir, "weather") }
  let(:provider) do
    double("provider",
           default_model: "gpt-5.4-mini",
           tracer: nil,
           user_role: "user",
           system_role: "system",
           developer_role: "developer")
  end
  let(:stream) { LLM::Stream.new }
  let(:ctx) { LLM::Context.new(provider, model: "gpt-5.4-mini", stream:) }

  def write(path, content)
    full = File.join(skill_dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  describe ".load" do
    before do
      write("SKILL.md", <<~MD)
        ---
        name: weather
        description: Get the current weather
        ---
        Use the helper tools to answer the user's question.
      MD
    end

    subject(:skill) { described_class.load(skill_dir) }

    it "loads metadata from SKILL.md" do
      expect(skill.name).to eq("weather")
      expect(skill.description).to eq("Get the current weather")
      expect(skill.frontmatter.name).to eq("weather")
      expect(skill.frontmatter.description).to eq("Get the current weather")
    end

    it "exposes the instructions body" do
      expect(skill.instructions).to include("Use the helper tools")
    end

    it "loads tools from SKILL.md" do
      write("SKILL.md", <<~MD)
        ---
        name: weather
        description: Get the current weather
        tools:
          - weather
        ---
        Use the helper tools to answer the user's question.
      MD
      expect(skill.tools).to eq([WeatherTool])
    end

    it "raises when a tool is missing" do
      write("SKILL.md", <<~MD)
        ---
        tools:
          - missing
        ---
        Use the helper tools to answer the user's question.
      MD
      expect { described_class.load(skill_dir) }.to raise_error(LLM::NoSuchToolError, /missing/)
    end
  end

  describe "#to_tool" do
    before do
      write("SKILL.md", <<~MD)
        ---
        name: weather
        description: Get the current weather
        tools:
          - weather
        ---
        Use the helper tools.
      MD
    end

    let(:skill) { described_class.load(skill_dir) }
    let(:tool) { skill.to_tool(ctx) }

    it "builds a tool with the skill metadata" do
      expect(tool.name).to eq("weather")
      expect(tool.description).to eq("Get the current weather")
    end

    it "binds tool execution back to the skill" do
      expect(skill).to receive(:call).with(ctx).and_return({content: "rain"})
      expect(tool.new.call).to eq({content: "rain"})
    end

    it "passes the function tracer back to the skill" do
      tracer = double("tracer", on_tool_start: nil, on_tool_finish: nil, on_tool_error: nil)
      provider = LLM.openai(key: "test")
      ctx = LLM::Context.new(provider, model: "gpt-5.4-mini", stream:)
      tool = skill.to_tool(ctx)
      function = tool.function.dup.tap do |fn|
        fn.id = "call_1"
        fn.arguments = {}
        fn.tracer = tracer
      end
      expect(skill).to receive(:call).with(ctx) do
        expect(ctx.llm.tracer).to equal(tracer)
        {content: "rain"}
      end
      expect(function.spawn(:thread).value.to_h).to eq(
        id: "call_1", name: "weather", value: {content: "rain"}
      )
    end
  end

  describe "#call" do
    before do
      write("SKILL.md", <<~MD)
        ---
        name: weather
        description: Get the current weather
        ---
        Use the helper tools.
      MD
    end

    let(:skill) { described_class.load(skill_dir) }
    let(:response) { double("response", content: "It is raining") }
    let(:res) { double("response", content: "It is raining", choices: [LLM::Message.new("assistant", "It is raining")]) }

    it "uses an internal agent and returns tool-shaped output" do
      allow_any_instance_of(LLM::Agent).to receive(:talk) do |_agent, prompt|
        expect(prompt).to eq("Solve the user's query.")
        response
      end
      expect(skill.call(ctx)).to eq({content: "It is raining"})
    end

    it "inherits the context mode" do
      responses_ctx = LLM::Context.new(provider, model: "gpt-5.4-mini", mode: :responses, stream:)
      expect(LLM::Context).to receive(:new).and_wrap_original do |original, prov, params|
        expect(prov).to be(provider)
        expect(params).to include(model: "gpt-5.4-mini", mode: :responses, stream:)
        original.call(prov, params)
      end
      allow_any_instance_of(LLM::Agent).to receive(:talk).and_return(response)
      skill.call(responses_ctx)
    end

    it "does not inherit the context schema" do
      schema_ctx = LLM::Context.new(provider, model: "gpt-5.4-mini", schema: :schema, stream:)
      expect(LLM::Context).to receive(:new).and_wrap_original do |original, prov, params|
        expect(prov).to be(provider)
        expect(params).to include(model: "gpt-5.4-mini", stream:)
        expect(params).not_to have_key(:schema)
        original.call(prov, params)
      end
      allow_any_instance_of(LLM::Agent).to receive(:talk).and_return(response)
      skill.call(schema_ctx)
    end

    it "inherits a curated slice of parent messages" do
      ctx.messages << LLM::Message.new(:system, "Ignore this")
      ctx.messages << LLM::Message.new(:user, "What is today's date?")
      ctx.messages << LLM::Message.new(:assistant, "Let me check.")
      ctx.messages << LLM::Message.new(:assistant, nil, tool_calls: [{id: "x", name: "weather", arguments: "{}"}])
      ctx.messages << LLM::Message.new(:tool, LLM::Function::Return.new("x", "weather", {content: "sunny"}))
      allow_any_instance_of(LLM::Agent).to receive(:talk) do |agent, _prompt|
        expect(agent.messages.map(&:content)).to eq(["Recent context:", "What is today's date?", "Let me check."])
        response
      end
      skill.call(ctx)
    end
  end
end
