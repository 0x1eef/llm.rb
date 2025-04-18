# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Anthropic: completions" do
  subject(:anthropic) { LLM.anthropic(token) }
  let(:token) { ENV["LLM_SECRET"] || "TOKEN" }

  context "when given a successful response",
          vcr: {cassette_name: "anthropic/completions/successful_response"} do
    subject(:response) { anthropic.complete("Hello, world", :user) }

    it "returns a completion" do
      expect(response).to be_a(LLM::Response::Completion)
    end

    it "returns a model" do
      expect(response.model).to eq("claude-3-5-sonnet-20240620")
    end

    it "includes token usage" do
      expect(response).to have_attributes(
        prompt_tokens: 10,
        completion_tokens: 30,
        total_tokens: 40
      )
    end

    context "with a choice" do
      subject(:choice) { response.choices[0] }

      it "has choices" do
        expect(choice).to have_attributes(
          role: "assistant",
          content: "Hello! How can I assist you today? Feel free to ask me any questions or let me know if you need help with anything."
        )
      end

      it "includes the response" do
        expect(choice.extra[:response]).to eq(response)
      end
    end
  end

  context "when given an unauthorized response",
          vcr: {cassette_name: "anthropic/completions/unauthorized_response"} do
    subject(:response) { anthropic.complete("Hello", :user) }
    let(:token) { "BADTOKEN" }

    it "raises an error" do
      expect { response }.to raise_error(LLM::Error::Unauthorized)
    end

    it "includes the response" do
      response
    rescue LLM::Error::Unauthorized => ex
      expect(ex.response).to be_kind_of(Net::HTTPResponse)
    end
  end
end
