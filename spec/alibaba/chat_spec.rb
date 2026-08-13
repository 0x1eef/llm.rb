# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Context: alibaba" do
  let(:provider) { LLM.alibaba(key:) }
  let(:llm) { provider }
  let(:key) { ENV["DASHSCOPE_API_KEY"] || "TOKEN" }
  let(:ctx) { LLM::Context.new(provider, params) }
  let(:params) { {} }

  context LLM::Context do
    include_examples "LLM::Context: completions", :alibaba
    include_examples "LLM::Context: completions contract", :alibaba
    include_examples "LLM::Context: text stream", :alibaba
  end

  ##
  # Alibaba's `qwen-flash` model keeps re-invoking a tool when the tool
  # only reports `{success: true}` without the actual output. To avoid an
  # open-ended tool loop in the recorded cassette, the tool returns a
  # fictional date so the model is satisfied after a single call.
  context "when given a tool call", vcr: {cassette_name: "alibaba/chat/llm_chat_stream_tool"} do
    let(:params) { {stream: true, tools: [tool]} }
    let(:tool) do
      LLM.function(:system) do |fn|
        fn.description "Runs system commands"
        fn.params { _1.object(command: _1.string.required) }
        fn.define { |command:| {success: true, output: "Mon Jul 10 12:34:56 UTC 2026"} }
      end
    end
    let(:prompt) do
      ctx.build_prompt do
        _1.user "You are a bot that can run UNIX system commands"
        _1.user "Hey, run the 'date' command"
      end
    end

    before { ctx.talk(prompt) }

    it "calls the function(s)" do
      ctx.talk ctx.pending_functions.map(&:call)
      expect(ctx.pending_functions).to be_empty
    end
  end

  context LLM::Function do
    include_examples "LLM::Context: functions", :alibaba
  end

  context LLM::Schema do
    include_examples "LLM::Context: schema", :alibaba
  end
end
