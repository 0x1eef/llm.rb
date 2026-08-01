# frozen_string_literal: true

require "setup"
require "fileutils"
require "tempfile"
require "tmpdir"

RSpec.describe LLM::Context do
  let(:ctx) { LLM::Context.new(provider, model:) }

  context "when given openai" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }

    context "#cost" do
      let(:cost) { LLM::Cost.new(input_costs: 0.000728125) }

      before do
        ctx.usage.input_tokens = 100
        ctx.usage.output_tokens = 50
        ctx.usage.cache_read_tokens = 25
        ctx.usage.reasoning_tokens = 10
      end

      it "delegates cost construction to LLM::Cost" do
        expect(LLM::Cost).to receive(:from).with(ctx).and_return(cost)
        expect(ctx.cost).to be(cost)
      end
    end

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(1050000) }
    end

    context "#params" do
      subject { ctx.params }
      it { is_expected.to include(model:) }
    end

    context "#wait" do
      let(:events) { [] }
      let(:stream) do
        events = self.events
        Class.new(LLM::Stream) do
          define_method(:on_tool_return) do |tool, result|
            events << [tool.name, result.name, result.value]
          end
        end.new
      end
      let(:ctx) { LLM::Context.new(provider, model:, stream:) }
      let(:function) do
        LLM::Function.new("system") do |fn|
          fn.define { {ok: true} }
        end.tap do |fn|
          fn.id = "call_1"
          fn.arguments = {}
        end
      end

      before do
        allow(ctx).to receive(:pending_functions).and_return([function].extend(LLM::Function::Array))
      end

      it "emits tool return callbacks for direct waits" do
        ctx.wait(:sequential)
        expect(events).to eq([["system", "system", {ok: true}]])
      end
    end

    context "#ask" do
      let(:response) { double(content: "Hello") }

      context "when given a plain prompt" do
        before do
          allow(ctx).to receive(:talk).with("Hello?").and_return(response)
        end

        it "returns the response" do
          expect(ctx.ask("Hello?")).to eq(response)
        end
      end

      context "when given file attachments" do
        let(:tempfile) do
          Tempfile.new(["llmrb", ".pdf"]).tap do |file|
            file.write("%PDF-1.4")
            file.flush
          end
        end
        let(:file_prompt) { ["What is this?", [ctx.local_file(tempfile.path)]] }

        before do
          allow(ctx).to receive(:talk).with(file_prompt).and_return(response)
        end

        after do
          tempfile.close!
        end

        it "attaches the local file to the prompt" do
          expect(ctx.ask("What is this?", with: tempfile.path)).to eq(response)
        end
      end

      context "when given a stream target" do
        let(:stream) { StringIO.new }

        before do
          allow(ctx).to receive(:talk).with("Hello?", stream:).and_return(response)
        end

        it "forwards the stream target" do
          expect(ctx.ask("Hello?", stream:)).to eq(response)
        end
      end
    end
  end

  context "when given anthropic" do
    let(:provider) { LLM.anthropic(key: "test") }
    let(:model) { "claude-opus-4-5" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(200000) }
    end
  end

  context "when given google" do
    let(:provider) { LLM.google(key: "test") }
    let(:model) { "gemini-2.5-flash" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(1048576) }
    end
  end

  context "when given deepseek" do
    let(:provider) { LLM.deepseek(key: "test") }
    let(:model) { "deepseek-chat" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(1000000) }
    end
  end

  context "when given a model that does not exist" do
    let(:provider) { LLM.deepseek(key: "test") }
    let(:model) { "does-not-exist" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to be_zero }
    end
  end

  context "when configured with responses mode" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:ctx) { LLM::Context.new(provider, model:, mode: :responses) }
    let(:responses) { double }
    let(:response) { double(choices: [LLM::Message.new("assistant", "Paris")]) }

    it "routes talk through the responses API" do
      allow(provider).to receive(:responses).and_return(responses)
      expect(responses).to receive(:create).with(
        array_including(have_attributes(content: "What is the capital of France?")),
        hash_including(model:)
      ).and_return(response)
      expect(ctx.talk("What is the capital of France?")).to eq(response)
    end

    it "calls the compactor before sending a request" do
      compactor = Class.new(LLM::Compactor) { def call(**opts) = nil }
      ctx = described_class.new(provider, model:, compactor:)
      allow(provider).to receive(:responses).and_return(responses)
      expect(responses).to receive(:create).ordered.and_return(response)
      ctx.talk("What is the capital of France?")
    end

    describe "input" do
      let(:existing_message) { LLM::Message.new(:user, "Earlier task context") }

      before do
        ctx.messages << existing_message
        allow(provider).to receive(:responses).and_return(responses)
      end

      it "holds the history, not the full messages" do
        expect(responses).to receive(:create).with(
          array_including(have_attributes(content: "What is the capital of France?")),
          hash_including(input: [existing_message])
        ).and_return(response)
        ctx.talk("What is the capital of France?")
      end
    end
  end

  context "when configured with skills" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:skill_path) { "/tmp/weather" }
    let(:tool) { double("tool") }
    let(:skill) { double("skill") }

    it "loads skills into tools" do
      expect(LLM::Skill).to receive(:load).with(skill_path).and_return(skill)
      expect(skill).to receive(:to_tool).with(instance_of(described_class)).and_return(tool)
      ctx = described_class.new(provider, model:, skills: [skill_path])
      expect(ctx.instance_variable_get(:@params)[:tools]).to eq([tool])
    end
  end

  context "when serializing tagged prompt objects" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:image_url) { "https://example.com/cat.png" }
    let(:remote_file) do
      LLM::Object.from(
        "file?" => true,
        "id" => "file_123",
        "filename" => "photo.png",
        "mime_type" => "image/png",
        "uri" => "https://example.com/photo.png",
        "file_type" => "image"
      )
    end
    let(:tempfile) do
      Tempfile.new(["llmrb", ".txt"]).tap do |file|
        file.write("hello")
        file.flush
      end
    end
    let(:tmpdir) { Dir.mktmpdir("llmrb-context") }
    let(:serialized) { File.join(tmpdir, "context.json") }
    let(:message) do
      LLM::Message.new("user", [
        ctx.image_url(image_url),
        ctx.local_file(tempfile.path),
        ctx.remote_file(remote_file)
      ])
    end
    let(:restored) do
      described_class.new(provider, model:).tap do |other|
        ctx.messages << message
        other.restore(string: ctx.to_json)
      end
    end
    let(:content) { restored.messages.first.content }

    after do
      tempfile.close!
      FileUtils.remove_entry(tmpdir)
    end

    context "#restore" do
      it "restores image_url content" do
        expect(content.fetch(0).kind).to eq(:image_url)
        expect(content.fetch(0).value).to eq(image_url)
      end

      it "restores local_file content" do
        expect(content.fetch(1).kind).to eq(:local_file)
        expect(content.fetch(1).value).to be_a(LLM::File)
        expect(content.fetch(1).value.path).to eq(tempfile.path)
      end

      it "restores remote_file content" do
        expect(content.fetch(2).kind).to eq(:remote_file)
        expect(content.fetch(2).value.file?).to eq(true)
        expect(content.fetch(2).value.id).to eq("file_123")
        expect(content.fetch(2).value.filename).to eq("photo.png")
        expect(content.fetch(2).value.mime_type).to eq("image/png")
        expect(content.fetch(2).value.uri).to eq("https://example.com/photo.png")
        expect(content.fetch(2).value.file_type).to eq("image")
      end
    end

    context "#serialize" do
      let(:restored) do
        described_class.new(provider, model:).tap do |other|
          ctx.messages << message
          ctx.serialize(path: serialized)
          other.restore(path: serialized)
        end
      end

      it "round-trips tagged prompt objects through a file" do
        expect(restored.messages.size).to eq(1)
        expect(restored.messages.first).to be_a(LLM::Message)
        expect(content.fetch(0).kind).to eq(:image_url)
        expect(content.fetch(0).value).to eq(image_url)
        expect(content.fetch(1).kind).to eq(:local_file)
        expect(content.fetch(1).value).to be_a(LLM::File)
        expect(content.fetch(1).value.path).to eq(tempfile.path)
        expect(content.fetch(2).kind).to eq(:remote_file)
        expect(content.fetch(2).value.file?).to eq(true)
        expect(content.fetch(2).value.id).to eq("file_123")
      end

      context "with assistant tool calls" do
        let(:message) do
          LLM::Message.new("assistant", nil, {
            tool_calls: [
              {id: "call_1", name: "system", arguments: {command: "date"}}
            ],
            original_tool_calls: [
              {"id" => "call_1", "type" => "function", "function" => {"name" => "system", "arguments" => "{\"command\":\"date\"}"}}
            ]
          })
        end
        before do
          restored
        end
        let(:restored_message) { restored.messages.first }
        let(:serialized_message) { JSON.parse(File.read(serialized)).fetch("messages").fetch(0) }
        let(:tool_calls) do
          restored_message.extra[:tool_calls].map do |tool|
            tool.to_h.merge("arguments" => tool.arguments.to_h)
          end
        end
        let(:original_tool_calls) do
          restored_message.extra[:original_tool_calls].map do |tool|
            tool.to_h.merge("function" => tool.function.to_h)
          end
        end

        it "restores the message as a tool call" do
          expect(restored_message.tool_call?).to eq(true)
        end

        it "serializes parsed tool calls under the tools key" do
          expect(serialized_message.fetch("tools")).to eq([
            {"id" => "call_1", "name" => "system", "arguments" => {"command" => "date"}}
          ])
        end

        it "round-trips parsed tool calls" do
          expect(tool_calls).to eq([
            {"id" => "call_1", "name" => "system", "arguments" => {"command" => "date"}}
          ])
        end

        it "round-trips original tool calls" do
          expect(original_tool_calls).to eq([
            {"id" => "call_1", "type" => "function", "function" => {"name" => "system", "arguments" => "{\"command\":\"date\"}"}}
          ])
        end
      end
    end
  end

  context "when a tool call already has a matching tool return" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:tool) do
      Class.new(LLM::Tool) do
        name "system"
        description "run shell commands"
      end
    end

    before do
      ctx.messages << LLM::Message.new("assistant", nil, {
        tools: [tool],
        tool_calls: [
          {id: "call_1", type: "function", function: {name: "system", arguments: {command: "date"}}}
        ]
      })
      ctx.messages << LLM::Message.new("tool", LLM::Function::Return.new("call_1", "system", {success: true}))
    end

    it "returns tool returns from ctx.returns" do
      expect(ctx.returns.map(&:id)).to eq(["call_1"])
    end

    it "does not include the tool call in ctx.pending_functions" do
      expect(ctx.pending_functions).to be_empty
    end
  end

  context "when configured with a tool instance" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:tool) do
      Class.new(LLM::Tool) do
        name "echo"

        def initialize(prefix:)
          @prefix = prefix
        end

        def call(value:)
          {"value" => "#{@prefix}: #{value}"}
        end
      end.new(prefix: "stateful")
    end
    let(:ctx) { LLM::Context.new(provider, model:, tools: [tool]) }

    before do
      ctx.messages << LLM::Message.new("assistant", nil, {
        tools: [tool],
        tool_calls: [
          {id: "call_1", name: "echo", arguments: {"value" => "hello"}}
        ]
      })
    end

    it "resolves and calls the bound tool instance" do
      result = ctx.pending_functions.fetch(0).call
      expect(result.to_h).to eq(
        id: "call_1",
        name: "echo",
        value: {"value" => "stateful: hello"}
      )
    end
  end

  context "when configured with a class-based tool" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:tool) do
      Class.new(LLM::Tool) do
        name "system"

        def call(command:)
          {"ok" => command == "date"}
        end
      end
    end
    let(:ctx) { LLM::Context.new(provider, model:, tools: [tool]) }

    before do
      ctx.messages << LLM::Message.new("assistant", nil, {
        tools: [tool],
        tool_calls: [
          {id: "call_1", name: "system", arguments: {"command" => "date"}}
        ]
      })
    end

    it "waits pending tool work with ractor concurrency" do
      expect(ctx.wait(:ractor).map(&:to_h)).to eq([
        {id: "call_1", name: "system", value: {"ok" => true}}
      ])
    end

    it "waits pending tool work with fork concurrency" do
      expect(ctx.wait(:fork).map(&:to_h)).to eq([
        {id: "call_1", name: "system", value: {"ok" => true}}
      ])
    end
  end

  context "#functions?" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }

    context "when unresolved functions exist in message history" do
      let(:tool) do
        Class.new(LLM::Tool) do
          name "system"

          def call(command:)
            {"ok" => command == "date"}
          end
        end
      end
      let(:ctx) { LLM::Context.new(provider, model:, tools: [tool]) }

      before do
        ctx.messages << LLM::Message.new("assistant", nil, {
          tools: [tool],
          tool_calls: [
            {id: "call_1", name: "system", arguments: {"command" => "date"}}
          ]
        })
      end

      it "returns true" do
        expect(ctx.pending_functions?).to eq(true)
      end
    end

    context "when the bound stream queue has pending work" do
      let(:stream) { LLM::Stream.new }
      let(:ctx) { LLM::Context.new(provider, model:, stream:) }
      let(:result) { LLM::Function::Return.new("call_1", "system", {"ok" => true}) }

      before do
        stream.queue << result
      end

      it "returns true" do
        expect(ctx.pending_functions?).to eq(true)
      end
    end

    context "when there is no queued or unresolved tool work" do
      it "returns false" do
        expect(ctx.pending_functions?).to eq(false)
      end
    end
  end

  context "when configured with a transformer" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:transformer_class) do
      Class.new(LLM::Transformer) do
        def call(message:, suffix:)
          LLM::Message.new(message.role, "#{message.content} #{suffix}", message.extra)
        end
      end
    end
    let(:ctx) { LLM::Context.new(provider, model:, transformer: transformer_class, transformer_options: {suffix: "[scrubbed]"}) }
    let(:responses) { provider.responses }
    let(:response) { double(choices: [LLM::Message.new("assistant", "hello")]) }
    let(:stream_class) do
      Class.new(LLM::Stream) do
        attr_reader :events

        def initialize
          @events = []
        end

        def on_transform(transformer)
          @events << [:start, transformer]
        end

        def on_transform_finish(transformer)
          @events << [:finish, transformer]
        end
      end
    end
    let(:stream) { stream_class.new }

    it "rewrites the most recent message before talk" do
      allow(provider).to receive(:responses).and_return(responses)
      expect(responses).to receive(:create).with(array_including(have_attributes(content: "hello [scrubbed]")), anything).and_return(response)
      ctx.talk("hello")
    end

    it "stores the transformed prompt in message history" do
      allow(provider).to receive(:responses).and_return(responses)
      allow(responses).to receive(:create).and_return(response)
      ctx.talk("hello")
      expect(ctx.messages.first.content).to eq("hello [scrubbed]")
    end

    it "notifies the stream when transform starts" do
      allow(provider).to receive(:responses).and_return(responses)
      allow(responses).to receive(:create).and_return(response)
      ctx.talk("hello", stream:)
      expect(stream.events.first.first).to eq(:start)
      expect(stream.events.first.last).to be_an_instance_of(transformer_class)
    end

    it "notifies the stream when transform finishes" do
      allow(provider).to receive(:responses).and_return(responses)
      allow(responses).to receive(:create).and_return(response)
      ctx.talk("hello", stream:)
      expect(stream.events.last.first).to eq(:finish)
      expect(stream.events.last.last).to be_an_instance_of(transformer_class)
    end
  end

  context "#spawn" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:tool) do
      Class.new(LLM::Tool) do
        name "system"

        def call(command:)
          {"ok" => command == "date"}
        end
      end.function.tap do |fn|
        fn.id = "call_1"
        fn.arguments = {"command" => "date"}
      end
    end

    it "spawns the function when no guard blocks it" do
      task = ctx.spawn(tool, :thread)
      expect(task.wait.to_h).to eq(
        id: "call_1",
        name: "system",
        value: {"ok" => true}
      )
    end

    it "returns a guarded tool error when the guard blocks it" do
      ctx.guard = Class.new do
        def call(_ctx)
          "stop"
        end
      end.new
      expect(ctx.spawn(tool, :thread).to_h).to eq(
        id: "call_1",
        name: "system",
        value: {error: true, type: LLM::GuardError.name, message: "stop"}
      )
    end
  end

  context "#usage" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }

    it "zero-fills missing token fields" do
      ctx.messages << LLM::Message.new("assistant", "hello", usage: LLM::Object.from(input_tokens: 3))
      expect(ctx.usage.input_tokens).to eq(3)
      expect(ctx.usage.output_tokens).to eq(0)
      expect(ctx.usage.reasoning_tokens).to eq(0)
      expect(ctx.usage.input_audio_tokens).to eq(0)
      expect(ctx.usage.output_audio_tokens).to eq(0)
      expect(ctx.usage.input_image_tokens).to eq(0)
      expect(ctx.usage.cache_write_tokens).to eq(0)
      expect(ctx.usage.total_tokens).to eq(0)
    end

    it "restores persisted compaction state" do
      ctx.restore(data: {"compacted" => true, "messages" => []})
      expect(ctx.compacted?).to eq(true)
    end
  end

  context "when configured with a stream that supports wait" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:stream) { LLM::Stream.new }
    let(:ctx) { LLM::Context.new(provider, model:, stream:) }
    let(:per_call_stream) { LLM::Stream.new }
    let(:responses) { provider.responses }
    let(:response) { double(choices: [LLM::Message.new("assistant", "hello", model:)]) }
    let(:guard) do
      Class.new do
        def call(_ctx)
          "stop"
        end
      end.new
    end
    let(:tool) do
      Class.new(LLM::Tool) do
        name "system"

        def call(command:)
          {"ok" => command == "date"}
        end
      end
    end

    it "forwards #wait to the configured stream when the queue has work" do
      stream.queue << LLM::Function::Return.new("call_1", "system", {"ok" => true})
      expect(ctx.wait(:thread)).to eq([LLM::Function::Return.new("call_1", "system", {"ok" => true})])
    end

    it "forwards #wait(:sequential) to the configured stream when the queue has work" do
      stream.queue << LLM::Function::Return.new("call_1", "system", {"ok" => true})
      expect(ctx.wait(:sequential)).to eq([LLM::Function::Return.new("call_1", "system", {"ok" => true})])
    end

    it "waits queued stream work even when a guard is configured" do
      ctx.guard = guard
      stream.queue << LLM::Function::Return.new("call_1", "system", {"ok" => true})
      expect(ctx.wait(:thread)).to eq([LLM::Function::Return.new("call_1", "system", {"ok" => true})])
    end

    it "falls back to pending functions when the queue is empty" do
      pending = [].extend(LLM::Function::Array)
      expect(ctx).to receive(:pending_functions).and_return(pending)
      expect(pending).to receive(:task).with(:thread).and_return(LLM::Function::Thread::Group.new([]))
      expect(ctx.wait(:thread)).to eq([])
    end

    it "flows through pending function spawn groups for #wait(:sequential)" do
      pending = [].extend(LLM::Function::Array)
      expect(ctx).to receive(:pending_functions).and_return(pending)
      expect(pending).to receive(:task).with(:sequential).and_return(LLM::Function::Sequential::Group.new([]))
      expect(ctx.wait(:sequential)).to eq([])
    end

    context "when given a per-call stream" do
      let(:ctx) { LLM::Context.new(provider, model:, stream:) }
      let(:result) { LLM::Function::Return.new("call_1", "system", {"ok" => true}) }

      before do
        allow(provider).to receive(:responses).and_return(responses)
        allow(responses).to receive(:create).and_return(response)
        ctx.talk("hello", stream: per_call_stream)
        per_call_stream.queue << result
      end

      it "waits queued stream work" do
        expect(ctx.wait(:thread)).to eq([result])
      end

      it "waits queued stream work with :call" do
        expect(ctx.wait(:sequential)).to eq([result])
      end

      it "clears the per-call stream after wait" do
        expect(ctx.instance_variable_get(:@stream)).to eq(per_call_stream)
        ctx.wait(:thread)
        expect(ctx.instance_variable_get(:@stream)).to be_nil
      end
    end

    context "with a guard that wants to stop execution" do
      let(:guard) do
        Class.new do
          def call(_ctx)
            "stop"
          end
        end.new
      end

      it "returns guarded results before spawning pending functions" do
        ctx.guard = guard
        ctx.messages << LLM::Message.new("assistant", nil, {
          tools: [tool],
          tool_calls: [
            {id: "call_1", name: "system", arguments: {"command" => "date"}}
          ]
        })
        pending = ctx.pending_functions
        expect(pending).not_to receive(:spawn)
        allow(ctx).to receive(:functions).and_return(pending)
        expect(ctx.wait(:thread).map(&:value)).to eq([{error: true, type: LLM::GuardError.name, message: "stop"}])
      end
    end
  end

  context "#interrupt!" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:responses) { provider.responses }

    it "forwards to the provider" do
      owner = Fiber.new {}
      ctx.instance_variable_set(:@owner, owner)
      expect(provider).to receive(:interrupt!).with(owner).and_return(nil)
      expect(ctx.interrupt!).to be_nil
    end

    it "tracks the executing fiber as the interrupt owner" do
      owner = Fiber.new do
        allow(provider).to receive(:responses).and_return(responses)
        allow(responses).to receive(:create).and_return(double(choices: [LLM::Message.new("assistant", "hello")]))
        ctx.talk("hello")
        expect(provider).to receive(:interrupt!).with(nil).and_return(nil)
        expect(ctx.interrupt!).to be_nil
      end
      owner.resume
    end

    context "when interrupting a call group during wait(:sequential)" do
      let(:tool) do
        Class.new(LLM::Tool) do
          name "slow"
          def call
            sleep 10
            {ok: true}
          end
        end
      end
      let(:ctx) { LLM::Context.new(provider, model:, tools: [tool]) }

      before do
        fn = tool.function
        fn.id = "call_1"
        fn.arguments = {}
        ctx.messages << LLM::Message.new("assistant", nil, {
          tools: [tool],
          tool_calls: [
            {id: "call_1", name: "slow", arguments: {}}
          ]
        })
      end

      it "raises LLM::Interrupt on the thread waiting for tool work" do
        thread = Thread.new do
          ctx.wait(:sequential)
        rescue LLM::Interrupt
          :interrupted
        end
        sleep 0.05
        ctx.interrupt!
        thread.join(2)
        expect(thread.value).to eq(:interrupted)
      end

      it "clears the queue after interrupt" do
        thread = Thread.new do
          ctx.wait(:sequential)
        rescue LLM::Interrupt
          :interrupted
        end
        sleep 0.05
        ctx.interrupt!
        thread.join(2)
        expect(ctx.instance_variable_get(:@queue)).to be_nil
      end
    end

    context "when queued tool work is running through a stream" do
      let(:stream) { LLM::Stream.new }
      let(:ctx) { LLM::Context.new(provider, model:, stream:) }
      let(:tool) do
        Class.new(LLM::Tool) do
          name "echo"
          description "echoes a value"

          def call(value:)
            sleep 10
            {value:}
          rescue LLM::Interrupt
            {value:, interrupted: true}
          end
        end.new
      end

      it "interrupts the queued tool" do
        task = tool.function.tap { _1.arguments = {value: "hello"} }.task(:thread)
        task.spawn
        stream.queue << task
        sleep 0.05 # let the thread enter the tool's call method
        expect(provider).to receive(:interrupt!).with(nil).ordered.and_return(nil)
        expect(ctx.interrupt!).to be_nil
        expect(task.wait.value).to eq({value: "hello", interrupted: true})
      end
    end

    context "when waiting on running tool work directly" do
      let(:stream) { LLM::Stream.new }
      let(:task_class) do
        Class.new do
          attr_reader :interrupted

          def interrupt!
            @interrupted = true
          end
        end
      end
      let(:task) { task_class.new }

      before do
        ctx.instance_variable_set(:@queue, stream.queue << task)
        allow(provider).to receive(:interrupt!).with(nil).and_return(nil)
        ctx.interrupt!
      end

      it "interrupts the provider request" do
        expect(provider).to have_received(:interrupt!).with(nil)
      end

      it "interrupts the active queue task" do
        expect(task.interrupted).to eq(true)
      end
    end

    context "when pending tool calls have no returns yet" do
      let(:tool) do
        Class.new(LLM::Tool) do
          name "echo"

          def call(value:)
            {value:}
          end
        end
      end

      before do
        fn = tool.function
        fn.id = "call_1"
        fn.arguments = {value: "hello"}
        ctx.messages << LLM::Message.new(
          "assistant",
          nil,
          tool_calls: [LLM::Object.from(id: fn.id, name: fn.name, arguments: LLM.json.dump(fn.arguments))],
          original_tool_calls: [{id: fn.id, type: "function", function: {name: fn.name, arguments: LLM.json.dump(fn.arguments)}}],
          tools: [tool]
        )
      end

      it "discards the turn without appending tool returns" do
        expect(provider).to receive(:interrupt!).with(nil).ordered.and_return(nil)
        expect(ctx.interrupt!).to be_nil
        expect(ctx.messages.last.role).to eq("assistant")
        expect(ctx.messages.last.tool_call?).to be true
      end
    end
  end

  context "#talk" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:responses) { provider.responses }
    let(:response) { double(choices: [LLM::Message.new("assistant", "hello")]) }

    it "calls the compactor before sending a completions request" do
      compactor_class = Class.new(LLM::Compactor) do
        def call(**opts) = nil
      end
      ctx = described_class.new(provider, model:, compactor: compactor_class)
      allow(provider).to receive(:responses).and_return(responses)
      expect(responses).to receive(:create).ordered.and_return(response)
      ctx.talk("hello")
    end

    it "binds the current context onto the stream" do
      stream = LLM::Stream.new
      ctx = described_class.new(provider, model:, stream:)
      allow(provider).to receive(:responses).and_return(responses)
      expect(responses).to receive(:create).ordered.and_return(response)
      ctx.talk("hello")
      expect(stream.ctx).to eq(ctx)
    end

    context "when given tool returns" do
      let(:tool) do
        Class.new(LLM::Tool) do
          name "system"
          description "run shell commands"
        end
      end
      let(:result) { LLM::Function::Return.new("call_1", "system", {ok: true}) }

      before do
        ctx.messages << LLM::Message.new("assistant", nil, {
          tools: [tool],
          tool_calls: [
            {id: "call_1", type: "function", function: {name: "system", arguments: {command: "date"}}}
          ]
        })
      end

      it "does not compact before sending tool returns" do
        allow(provider).to receive(:responses).and_return(responses)
        expect(responses).to receive(:create).ordered.and_return(response)
        ctx.talk([result])
      end
    end
  end
end
