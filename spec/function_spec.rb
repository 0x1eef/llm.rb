# frozen_string_literal: true

require "setup"
require "timeout"
require "tmpdir"

RSpec.describe LLM::Function do
  let(:tool_class) do
    Class.new(LLM::Tool) do
      name "system"
      def call(command:)
        {"ok" => command == "date"}
      end
    end
  end
  let(:tool) do
    tool_class.function.dup.tap do |fn|
      fn.id = "call_1"
      fn.arguments = {"command" => "date"}
    end
  end

  describe "#task" do
    subject(:task) { tool.task(strategy) }

    let(:strategy) { :ractor }

    context "when using sequential concurrency" do
      let(:strategy) { :sequential }

      it "returns the tool result" do
        expect(task.wait.to_h).to eq(id: "call_1", name: "system", value: {"ok" => true})
      end
    end

    describe "#value" do
      subject { task.value.to_h }
      it { is_expected.to eq(id: "call_1", name: "system", value: {"ok" => true}) }
    end

    describe "#alive?" do
      slow_tool = Class.new(LLM::Tool) do
        name "slow"
        def call
          sleep 0.5
          {"ok" => true}
        end
      end.function.dup.tap do |fn|
        fn.id = "call_2"
        fn.arguments = {}
      end

      it "tracks task liveness" do
        task = slow_tool.task(:ractor)
        task.spawn
        sleep 0.01 until task.alive?
        expect(task.alive?).to be(true)
        task.wait
        expect(task.alive?).to be(false)
      end
    end

    describe "#interrupt!" do
      before do
        skip "not supported by yajl or oj" unless ENV.fetch("JSON_PARSER", "json") == "json"
      end

      let(:tool) do
        Class.new(LLM::Tool) do
          name "slow"
          def call
            sleep 2
            {ok: true}
          end
        end
      end

      it "interrupts the tool execution" do
        fn = tool.function.dup.tap {
          _1.id = "call_3"
          _1.arguments = {}
        }
        task = fn.task(:ractor)
        task.spawn
        sleep 0.05 until task.alive?
        task.interrupt!
        expect(task.wait.to_h).to eq(id: "call_3", name: "slow", value: {cancelled: true, reason: "interrupted"})
      end

      it "returns nil from interrupt!" do
        task = tool.function.dup.tap {
          _1.id = "call_4"
          _1.arguments = {}
        }.task(:ractor)
        expect(task.interrupt!).to be_nil
      end
    end

    it "rejects proc-defined functions" do
      fn = LLM::Function.new("echo")
      fn.arguments = {"value" => "hello"}
      fn.define { |value:| {value:} }
      expect { fn.task(:ractor) }.to raise_error(
        LLM::RactorError,
        "Ractor concurrency only supports class-based tools"
      )
    end

    context "when configured with a tracer" do
      let(:tracer) { double("tracer", on_tool_start: :span, on_tool_finish: nil) }

      before do
        tool.tracer = tracer
        tool.model = "gpt-4.1"
      end

      it "traces the ractor-backed tool call" do
        expect(task.wait.to_h).to eq(id: "call_1", name: "system", value: {"ok" => true})
        expect(tracer).to have_received(:on_tool_start).with(
          id: "call_1",
          name: "system",
          arguments: {"command" => "date"},
          model: "gpt-4.1"
        )
        expect(tracer).to have_received(:on_tool_finish).with(
          result: have_attributes(id: "call_1", name: "system", value: {"ok" => true}),
          span: :span
        )
      end
    end

    context "when using fork concurrency" do
      let(:strategy) { :fork }

      it "returns the tool result" do
        expect(task.wait.to_h).to eq(id: "call_1", name: "system", value: {"ok" => true})
      end

      describe "error handling" do
        let(:error_tool) do
          tool_class.function.dup.tap do |fn|
            fn.id = "call_4"
            fn.arguments = {"paths" => ["CHANGELOG.md"]}
          end
        end

        it "returns tool errors without hanging" do
          result = Timeout.timeout(1) { error_tool.task(:fork).wait.to_h }
          expect(result).to eq(
            id: "call_4",
            name: "system",
            value: {error: true, type: "ArgumentError", message: "missing keyword: :command"}
          )
        end
      end

      context "when configured with a tracer" do
        let(:tracer) { double("tracer", on_tool_start: :span, on_tool_finish: nil) }

        before do
          tool.tracer = tracer
          tool.model = "gpt-4.1"
        end

        it "traces the fork-backed tool call" do
          expect(task.wait.to_h).to eq(id: "call_1", name: "system", value: {"ok" => true})
          expect(tracer).to have_received(:on_tool_start).with(
            id: "call_1",
            name: "system",
            arguments: {"command" => "date"},
            model: "gpt-4.1"
          )
          expect(tracer).to have_received(:on_tool_finish).with(
            result: have_attributes(id: "call_1", name: "system", value: {"ok" => true}),
            span: :span
          )
        end
      end

      let(:interrupt_tool) do
        tool_class = Class.new(LLM::Tool) do
          name "interruptible"

          define_method(:call) do
            sleep 10
            {"ok" => true}
          rescue LLM::Interrupt
            {"ok" => true, "interrupted" => true}
          end
        end
        tool_class.function.dup.tap do |fn|
          fn.id = "call_3"
          fn.arguments = {}
        end
      end

      it "delivers interrupts to the child tool" do
        task = interrupt_tool.task(:fork)
        task.spawn
        sleep 0.05 until task.alive?
        task.interrupt!
        expect(task.wait.to_h).to eq(id: "call_3", name: "interruptible", value: {"ok" => true, "interrupted" => true})
      end

      it "propagates LLM::Interrupt when the tool does not rescue it" do
        tool_class = Class.new(LLM::Tool) do
          name "brittle"

          define_method(:call) do
            sleep 10
            {"ok" => true}
          end
        end
        fn = tool_class.function.dup.tap do |f|
          f.id = "call_4"
          f.arguments = {}
        end
        task = fn.task(:fork)
        task.spawn
        sleep 0.05 until task.alive?
        task.interrupt!
        expect { task.wait }.to raise_error(LLM::Interrupt)
      end
    end

    context "when using fiber concurrency without a scheduler" do
      it "raises a clear error" do
        task = tool.task(:fiber)
        expect { task.spawn }.to raise_error(
          ArgumentError,
          "Fiber concurrency requires Fiber.scheduler"
        )
      end
    end
  end

  describe LLM::Function::Sequential::Group do
    describe "#interrupt!" do
      subject(:group) { LLM::Function::Sequential::Group.new([function]) }

      let(:fn_class) do
        Class.new(LLM::Tool) do
          name "slow"
          def call
            sleep 10
            {ok: true}
          end
        end
      end
      let(:function) do
        fn_class.function.dup.tap do |fn|
          fn.id = "call_1"
          fn.arguments = {}
        end
      end

      it "raises LLM::Interrupt on the thread running wait" do
        thread = Thread.new { group.wait }
        thread.report_on_exception = false
        sleep 0.05
        group.interrupt!
        expect { thread.value }.to raise_error(LLM::Interrupt)
      end

      it "interrupts the currently running tool execution" do
        thread = Thread.new {
          group.wait rescue LLM::Interrupt
          :interrupted
        }
        thread.report_on_exception = false
        sleep 0.05
        group.interrupt!
        expect(thread.value).to eq(:interrupted)
      end

      it "is a no-op when wait has not been called" do
        expect(group.interrupt!).to be_nil
      end

      it "is a no-op when wait has completed" do
        fn = fn_class.function.dup.tap do |f|
          f.define { {ok: true} }
          f.id = "call_2"
          f.arguments = {}
        end
        LLM::Function::Sequential::Group.new([fn]).wait
        expect(group.interrupt!).to be_nil
      end
    end
  end

  describe LLM::Function::Task do
    describe "#interrupt!" do
      let(:fn) do
        LLM::Function.new("test") { _1.define { {ok: true} } }.tap do |f|
          f.id = "call_1"
          f.arguments = {}
        end
      end

      context "when wrapping a Thread" do
        it "raises LLM::Interrupt on the thread" do
          slow = LLM::Function.new("slow") { _1.define { sleep 10; {ok: true} } }
          slow.id = "call_1"
          slow.arguments = {}
          task = LLM::Function::Thread::Task.new(slow)
          task.spawn
          sleep 0.05 until task.alive?
          task.interrupt!
          expect { task.wait }.to raise_error(LLM::Interrupt)
        end
      end

      context "when wrapping a Fiber" do
        it "does not raise on a dead fiber" do
          fiber = Fiber.new { :done }.tap(&:resume)
          expect { LLM::Function::Fiber::Task.new(fn).interrupt! }.not_to raise_error
        end
      end

      context "when wrapping an Async::Task" do
        before do
          require "async"
          Console.logger.level = :fatal if defined?(Console)
        end

        it "raises LLM::Interrupt on the underlying fiber" do
          slow = LLM::Function.new("slow") { _1.define { sleep 10; {ok: true} } }
          slow.id = "call_1"
          slow.arguments = {}
          reactor = LLM::Function::Async::Reactor.new
          task = LLM::Function::Async::Task.new(slow, reactor:)
          task.spawn
          sleep 0.05 until task.alive?
          task.interrupt!
          expect { task.wait }.to raise_error(LLM::Interrupt)
        ensure
          reactor&.stop
        end

        it "is a no-op on a dead async task" do
          reactor = LLM::Function::Async::Reactor.new
          task = LLM::Function::Async::Task.new(fn, reactor:).tap(&:wait)
          expect { task.interrupt! }.not_to raise_error
        ensure
          reactor&.stop
        end
      end

      context "when the task responds to interrupt!" do
        let(:interruptible) do
          Class.new do
            attr_reader :interrupted
            def initialize
              @interrupted = false
            end
            def interrupt!
              @interrupted = true
            end
          end.new
        end

        it "calls interrupt! on the task if it responds to it" do
          interruptible.interrupt!
          expect(interruptible.interrupted).to be true
        end
      end

      it "returns nil" do
        task = LLM::Function::Thread::Task.new(fn).tap(&:spawn)
        expect(task.interrupt!).to be_nil
      end
    end
  end

  describe LLM::Function::Array do
    subject { [tool].extend(LLM::Function::Array).wait(:ractor).map(&:to_h) }
    it { is_expected.to eq([{id: "call_1", name: "system", value: {"ok" => true}}]) }

    it "waits on forked work" do
      expect([tool].extend(LLM::Function::Array).wait(:fork).map(&:to_h)).to eq(
        [{id: "call_1", name: "system", value: {"ok" => true}}]
      )
    end
  end

  describe "#params" do
    context "when no parameters are defined" do
      it "returns an empty schema hash" do
        fn = tool_class.function
        expect(fn.params).to eq(LLM::Schema::Object.new({}))
      end
    end

    context "when parameters are defined" do
      it "returns the defined schema" do
        tool = Class.new(LLM::Tool) do
          name "greeter"
          parameter :name, String, "The name"
          required %i[name]
        end
        expect(tool.function.params[:name]).to_not be_nil
      end
    end
  end
end
