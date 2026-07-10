# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Mistral: ocr" do
  let(:mistral) { LLM.mistral(key:) }
  let(:key) { ENV["MISTRAL_SECRET"] || "TOKEN" }

  context "when given a successful document_url response",
          vcr: {cassette_name: "mistral/ocr/successful_document_url"} do
    subject(:response) do
      mistral.ocr(document_url: "https://arxiv.org/pdf/2201.04234")
    end

    it "returns an OCR response" do
      expect(response).to be_instance_of(LLM::Response)
    end

    it "returns a model" do
      expect(response.model).to eq("mistral-ocr-latest")
    end

    it "returns pages" do
      expect(response.pages).to be_instance_of(Array)
    end
  end

  context "when given a successful image_url response",
          vcr: {cassette_name: "mistral/ocr/successful_image_url"} do
    subject(:response) do
      mistral.ocr(image_url: "https://raw.githubusercontent.com/github/explore/main/topics/ruby/ruby.png")
    end

    it "returns an OCR response" do
      expect(response).to be_instance_of(LLM::Response)
    end

    it "returns a model" do
      expect(response.model).to eq("mistral-ocr-latest")
    end

    it "returns pages" do
      expect(response.pages).to be_instance_of(Array)
    end
  end
end
