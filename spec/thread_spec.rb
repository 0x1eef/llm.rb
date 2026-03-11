# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Provider do
  before do
    provider.class.module_eval do
      public :headers, :execute
    end
  end

  after do
    provider.class.module_eval do
      private :headers, :execute
    end
  end

  let(:tracer) do
    Class.new do
      attr_reader :finishes

      def initialize
        @finishes = []
      end

      def on_request_start(operation:, model: nil)
        {operation:, model:}
      end

      def on_request_finish(operation:, res:, model: nil, span: nil)
        @finishes << {operation:, model:, res:, span:}
        nil
      end
    end
  end

  let(:provider) { LLM.openai(key: "test") }

  describe "#headers" do
    let(:count) { 50 }
    let(:errors) { Queue.new }
    let(:writers) do
      count.times.map do |i|
        Thread.new do
          provider.with(headers: {"X-Thread-#{i}" => i.to_s})
        end
      end
    end
    let(:readers) do
      count.times.map do
        Thread.new do
          25.times { provider.headers }
        rescue => ex
          errors << ex
        end
      end
    end

    it "keeps all writes" do
      writers.each(&:join)
      headers = provider.headers
      count.times do |i|
        expect(headers["X-Thread-#{i}"]).to eq(i.to_s)
      end
    end

    it "handles reads while writing" do
      [*writers, *readers].each(&:join)
      expect(errors).to be_empty
      headers = provider.headers
      count.times do |i|
        expect(headers["X-Thread-#{i}"]).to eq(i.to_s)
      end
    end
  end

  describe "#tracer=" do
    let(:started) { Queue.new }
    let(:release) { Queue.new }
    let(:tracer1) { tracer.new }
    let(:tracer2) { tracer.new }

    before do
      stub_request(:get, "https://api.openai.com/v1/models")
        .to_return do
          started << true
          release.pop
          {status: 200, body: "{}", headers: {"Content-Type" => "application/json"}}
        end
    end

    context "without in-flight requests" do
      it "replaces the tracer" do
        provider.tracer = tracer1
        provider.tracer = tracer2
        expect(provider.tracer).to equal(tracer2)
      end
    end

    context "with concurrent tracer writes" do
      let(:count) { 20 }
      let(:errors) { Queue.new }
      let(:mutators) do
        count.times.map do
          Thread.new do
            local_tracer = tracer.new
            20.times do |i|
              provider.tracer = (i.even? ? local_tracer : nil)
            end
          rescue => ex
            errors << ex
          end
        end
      end

      it "does not raise errors" do
        mutators.each(&:join)
        expect(errors).to be_empty
      end

      it "assigns the tracer" do
        mutators.each(&:join)
        expect(provider.tracer).not_to be_nil
      end
    end

    context "when request runs in another thread" do
      it "uses the request thread tracer" do
        _res, _span, request_tracer = run_in_flight_request
        expect(request_tracer).to equal(tracer1)
      end

      it "ignores tracer changes from other threads" do
        _res, _span, request_tracer = run_in_flight_request do
          provider.tracer = tracer2
        end
        expect(request_tracer).to equal(tracer1)
      end

      it "finishes on the request thread tracer" do
        _res, span, request_tracer = run_in_flight_request do
          provider.tracer = tracer2
        end
        request_tracer.on_request_finish(operation: "chat", model: "gpt-test", res: Object.new, span:)
        expect(tracer1.finishes.size).to eq(1)
        expect(tracer2.finishes).to eq([])
      end
    end

    context "when request thread tracer is nil" do
      it "uses null tracer for that thread" do
        _res, _span, request_tracer = run_in_flight_request(request_thread_tracer: nil)
        expect(request_tracer).to be_a(LLM::Tracer::Null)
      end
    end

    def run_in_flight_request(request_thread_tracer: tracer1)
      t = Thread.new do
        provider.tracer = request_thread_tracer
        req = Net::HTTP::Get.new("/v1/models", provider.headers)
        provider.execute(request: req, operation: "chat", model: "gpt-test")
      end
      started.pop
      yield if block_given?
      release << true
      t.value
    end
  end
end
