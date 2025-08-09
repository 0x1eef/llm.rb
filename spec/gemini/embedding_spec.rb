# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::OpenAI: embeddings" do
  let(:gemini) { LLM.gemini(key:) }
  let(:key) { ENV["GEMINI_SECRET"] || "TOKEN" }

  context "when given a successful response",
          vcr: {cassette_name: "gemini/embeddings/successful_response", match_requests_on: [:method]} do
    subject(:response) { gemini.embed("Hello, world") }

    it "returns an embedding" do
      expect(response).to be_instance_of(LLM::Response)
    end

    it "has embeddings" do
      expect(response.embedding.values).to be_instance_of(Array)
    end
  end
end
