# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::OpenAI::ResponseAdapter::Responds" do
  let!(:provider) { LLM.openai(key: "test") }
  let(:body) do
    LLM::Object.from(
      model: "test-model",
      usage: nil,
      output: [
        {
          type: "function_call",
          call_id: "call_1",
          name: "system",
          arguments: "{\"command\":\"date"
        }
      ]
    )
  end
  let(:http_response) { Struct.new(:body).new(body) }
  let(:response) { LLM::Response.new(http_response) }
  let(:responds) { LLM::OpenAI::ResponseAdapter.adapt(response, type: :responds) }

  it "tolerates malformed tool arguments" do
    expect(responds.choices[0].extra[:tool_calls]).to eq(
      [{id: "call_1", name: "system", arguments: {}}]
    )
  end
end
