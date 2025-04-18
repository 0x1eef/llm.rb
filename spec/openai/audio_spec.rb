# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::OpenAI::Audio" do
  let(:token) { ENV["LLM_SECRET"] || "TOKEN" }
  let(:provider) { LLM.openai(token) }

  context "when given a successful creation",
        vcr: {cassette_name: "openai/audio/successful_creation"} do
    subject(:response) { provider.audio.create_speech(input: "A dog on a rocket to the moon") }

    it "is successful" do
      expect(response).to be_instance_of(OpenStruct)
    end

    it "returns an audio" do
      expect(response.audio).to be_instance_of(StringIO)
    end
  end

  context "when given a successful transcription",
        vcr: {cassette_name: "openai/audio/successful_transcription"} do
    subject(:response) do
      provider.audio.create_transcription(
        file: LLM::File("spec/fixtures/audio/rocket.mp3")
      )
    end

    it "is successful" do
      expect(response).to be_instance_of(OpenStruct)
    end

    it "returns a transcription" do
      expect(response.text).to eq("A dog on a rocket to the moon.")
    end
  end

  context "when given a successful translation",
        vcr: {cassette_name: "openai/audio/successful_translation"} do
    subject(:response) do
      provider.audio.create_translation(
        file: LLM::File("spec/fixtures/audio/bismillah.mp3")
      )
    end

    it "is successful" do
      expect(response).to be_instance_of(OpenStruct)
    end

    it "returns a translation (Arabic => English)" do
      expect(response.text).to eq("In the name of Allah, the Beneficent, the Merciful.")
    end
  end
end
