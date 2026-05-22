# frozen_string_literal: true

require "setup"
require "tempfile"

RSpec.describe LLM::File do
  describe "#exist?" do
    subject(:file) { described_class.new(path) }

    context "when the file exists" do
      let(:tempfile) do
        Tempfile.new(["llmrb", ".txt"]).tap do |f|
          f.write("hello")
          f.flush
        end
      end
      let(:path) { tempfile.path }

      after do
        tempfile.close!
      end

      it "returns true" do
        expect(file.exist?).to eq(true)
      end
    end

    context "when the file does not exist" do
      let(:path) { "/tmp/llmrb-does-not-exist-#{Process.pid}-#{rand(1000)}.txt" }

      it "returns false" do
        expect(file.exist?).to eq(false)
      end
    end
  end
end
