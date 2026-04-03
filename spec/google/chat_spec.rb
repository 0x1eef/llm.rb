# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Context: google" do
  let(:provider) { LLM.google(key:) }
  let(:llm) { provider }
  let(:key) { ENV["GEMINI_SECRET"] || "TOKEN" }
  let(:ctx) { LLM::Context.new(provider, params) }
  let(:params) { {} }

  context LLM do
    include_examples "LLM: web search", :google, match_requests_on: [:method]
  end

  context LLM::Context do
    include_examples "LLM::Context: completions", :google, match_requests_on: [:method]
    include_examples "LLM::Context: completions contract", :google, match_requests_on: [:method]
    include_examples "LLM::Context: text stream", :google, match_requests_on: [:method]
    include_examples "LLM::Context: tool stream", :google, match_requests_on: [:method]

    context "with tool stream response metadata",
            vcr: {cassette_name: "google/chat/llm_chat_stream_tool_metadata", match_requests_on: [:method]} do
      let(:params) { {stream: true, tools: [tool]} }
      let(:tool) do
        LLM.function(:system) do |fn|
          fn.description "Runs system commands"
          fn.params { _1.object(command: _1.string.required) }
          fn.define { |command:| {success: Kernel.system(command)} }
        end
      end
      let(:prompt) do
        ctx.build_prompt do
          _1.user "You are a bot that can run UNIX system commands"
          _1.user "Hey, run the 'date' command"
        end
      end

      before { ctx.talk(prompt) }

      it "preserves thoughtSignature on functionCall parts" do
        message = ctx.messages.find(&:assistant?)
        part = message.response.body.candidates[0].content.parts[0]
        expect(part.thoughtSignature).to be_a(String)
      end
    end
  end

  context LLM::Function do
    include_examples "LLM::Context: functions", :google, match_requests_on: [:method]
  end

  context LLM::File do
    include_examples "LLM::Context: files", :google, match_requests_on: [:method]
  end

  context LLM::Schema do
    include_examples "LLM::Context: schema", :google, match_requests_on: [:method]
  end
end
