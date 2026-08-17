# frozen_string_literal: true

RSpec.shared_examples "LLM::Agent: skill" do |dirname, options = {}|
  vcr = lambda do |basename|
    {vcr: {cassette_name: "#{dirname}/chat/#{basename}"}.merge(options)}
  end

  context "when the model calls a skill", vcr.call("llm_chat_skill_stream") do
    let(:events) { [] }
    let(:stream) do
      events = self.events
      Class.new(LLM::Stream) do
        define_method(:on_skill_call) do |skill|
          events << [:call, skill.name]
        end
        define_method(:on_skill_return) do |skill, result|
          events << [:return, skill.name, result]
        end
      end.new
    end
    let(:tool) do
      Class.new(LLM::Tool) do
        name "weather"
        description "Get the current weather"

        def call(**)
          {content: "sunny"}
        end
      end
    end
    let(:skill_dir) do
      dir = File.join(Dir.tmpdir, "skills_spec_#{$$}")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "SKILL.md"), <<~MD)
        ---
        name: weather
        description: Get the current weather
        tools:
          - weather
        ---
        Use the weather tool to report the current weather.
      MD
      dir
    end
    let(:params) { {skills: [skill_dir], tools: [tool], stream:} }
    let(:agent) { LLM::Agent.new(llm, params) }
    let(:run) { agent.talk("Use the weather skill") }

    context "with stream hooks" do
      it "fires on_skill_call before on_skill_return" do
        run
        expect(events.map(&:first)).to eq([:call, :return])
      end

      it "passes the skill to both hooks" do
        run
        expect(events.map { _1[1] }).to eq(%w[weather weather])
      end

      it "passes a response to on_skill_return" do
        run
        expect(events.last[2]).to be_a(LLM::Response)
      end
    end

    context "with the conversation" do
      it "records the skill subagent's turn in the parent" do
        run
        expect(agent.messages.size).to be >= 2
      end
    end
  end
end