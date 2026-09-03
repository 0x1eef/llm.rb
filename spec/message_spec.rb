# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Message do
  let(:image_url) { LLM::Object.from(value: "https://example.com/cat.png", kind: :image_url) }
  let(:local_file) { LLM::Object.from(value: LLM.File(__FILE__), kind: :local_file) }
  let(:remote_file) do
    LLM::Object.from(value: LLM::Object.from("id" => "file_123"), kind: :remote_file)
  end

  describe "#reasoning_content" do
    subject(:message) do
      described_class.new("assistant", "answer", reasoning_content: "thought")
    end

    it "returns the reasoning content" do
      expect(message.reasoning_content).to eq("thought")
    end

    it "includes reasoning content in the hash representation" do
      expect(message.to_h[:reasoning_content]).to eq("thought")
    end
  end

  describe "#to_h" do
    subject(:message) do
      described_class.new(
        "assistant",
        nil,
        reasoning_content: "thought",
        tool_calls: [LLM::Object.from("id" => "call_1")]
      )
    end

    it "preserves nil content" do
      expect(message.to_h[:content]).to be_nil
    end

    it "normalizes tool calls to hashes" do
      expect(message.to_h[:tools]).to eq([{"id" => "call_1"}])
    end

    it "includes the created_at timestamp" do
      expect(message.to_h[:created_at]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\z/)
    end
  end

  describe "#created_at" do
    subject(:message) { described_class.new("user", "hi") }

    it "returns a Time" do
      expect(message.created_at).to be_a(Time)
    end

    it "is set at initialize time" do
      expect(message.created_at).to be_within(1).of(Time.now.utc)
    end

    context "when given a created_at in extra" do
      let(:time) { Time.utc(2025, 1, 1) }
      let(:rfc3339) { "2025-01-01T00:00:00Z" }
      subject(:message) { described_class.new("user", "hi", created_at: rfc3339) }

      it "returns the given time" do
        expect(message.created_at).to eq(time)
      end
    end
  end

  describe "#image_url?" do
    subject(:message) { described_class.new("user", content) }

    context "when the message contains an image_url" do
      let(:content) { [image_url, local_file] }
      it { is_expected.to be_image_url }
    end

    context "when the message does not contain an image_url" do
      let(:content) { [local_file, remote_file] }
      it { is_expected.not_to be_image_url }
    end
  end

  describe "#image_urls" do
    subject(:message) { described_class.new("user", [image_url, local_file]) }

    it "returns image_url content items" do
      expect(message.image_urls).to eq([image_url])
    end
  end

  describe "#file?" do
    subject(:message) { described_class.new("user", content) }

    context "when the message contains a local file" do
      let(:content) { [local_file] }
      it { is_expected.to be_file }
    end

    context "when the message contains a remote file" do
      let(:content) { [remote_file] }
      it { is_expected.to be_file }
    end

    context "when the message does not contain a file" do
      let(:content) { [image_url] }
      it { is_expected.not_to be_file }
    end
  end

  describe "#files" do
    subject(:message) { described_class.new("user", [image_url, local_file, remote_file]) }

    it "returns local and remote file content items" do
      expect(message.files).to eq([local_file, remote_file])
    end
  end
end
