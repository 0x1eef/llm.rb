# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Bot: gemini" do
  let(:described_class) { LLM::Bot }
  let(:provider) { LLM.gemini(key:) }
  let(:llm) { provider }
  let(:key) { ENV["GEMINI_SECRET"] || "TOKEN" }
  let(:bot) { described_class.new(provider, params) }
  let(:params) { {} }

  context LLM do
    include_examples "LLM: web search", :gemini, match_requests_on: [:method]
  end

  context LLM::Bot do
    include_examples "LLM::Bot: completions", :gemini, match_requests_on: [:method]
    include_examples "LLM::Bot: completions contract", :gemini, match_requests_on: [:method]
    include_examples "LLM::Bot: text stream", :gemini, match_requests_on: [:method]
    include_examples "LLM::Bot: tool stream", :gemini, match_requests_on: [:method]

    context "with tool stream response metadata",
            vcr: {cassette_name: "gemini/chat/llm_chat_stream_tool_metadata", match_requests_on: [:method]} do
      let(:params) { {stream: true, tools: [tool]} }
      let(:tool) do
        LLM.function(:system) do |fn|
          fn.description "Runs system commands"
          fn.params { _1.object(command: _1.string.required) }
          fn.define { |command:| {success: Kernel.system(command)} }
        end
      end
      let(:prompt) do
        bot.build_prompt do
          _1.user "You are a bot that can run UNIX system commands"
          _1.user "Hey, run the 'date' command"
        end
      end

      before { bot.chat(prompt) }

      it "preserves thoughtSignature on functionCall parts" do
        message = bot.messages.find(&:assistant?)
        part = message.response.body.candidates[0].content.parts[0]
        expect(part.thoughtSignature).to be_a(String)
      end
    end
  end

  context LLM::Function do
    include_examples "LLM::Bot: functions", :gemini, match_requests_on: [:method]
  end

  context LLM::File do
    include_examples "LLM::Bot: files", :gemini, match_requests_on: [:method]
  end

  context LLM::Schema do
    include_examples "LLM::Bot: schema", :gemini, match_requests_on: [:method]
  end
end
