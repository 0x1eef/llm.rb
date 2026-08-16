# frozen_string_literal: true

require "setup"
require "llm/providers/alibaba"

RSpec.describe LLM::Alibaba::ErrorHandler do
  subject(:handler) { described_class.new(tracer, span, response) }

  let(:tracer) { LLM::Tracer::Null.new(nil) }
  let(:span) { nil }

  context "when response is an insufficient quota error" do
    let(:response) { Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests") }
    let(:body) do
      LLM::Object.from(
        "error" => {
          "type" => "insufficient_quota",
          "code" => "insufficient_quota",
          "message" => "Allocated quota exceeded"
        }
      )
    end

    before { allow(response).to receive(:body).and_return(body) }

    it "raises LLM::InsufficientQuotaError" do
      expect { handler.raise_error! }.to raise_error(LLM::InsufficientQuotaError)
    end

    it "is a LLM::RateLimitError" do
      expect(captured_error).to be_a(LLM::RateLimitError)
    end
  end

  context "when response is a genuine rate limit" do
    let(:response) { Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests") }

    before { allow(response).to receive(:body).and_return("{}") }

    it "raises LLM::RateLimitError" do
      expect { handler.raise_error! }.to raise_error(LLM::RateLimitError)
    end
  end

  def captured_error
    handler.raise_error!
  rescue => ex
    ex
  end
end
