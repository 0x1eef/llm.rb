# frozen_string_literal: true

require "setup"
require "llm/tools/exec"

RSpec.describe LLM::Tool::Exec do
  let(:tool) { described_class.new }
  let(:command) do
    instance_double(Test::Command, running?: false, success?: true, stdout: "hi\n", stderr: "")
  end

  describe ".function" do
    let(:params) { described_class.function.params }

    it "defines the name param" do
      expect(params.properties[:name]).to be_a(LLM::Schema::String)
    end

    it "marks the name param as required" do
      expect(params.properties[:name]).to be_required
    end

    it "has a timeout parameter with a default" do
      expect(params.properties[:timeout].default).to eq(60)
    end
  end

  describe "#call" do
    it "raises when the command exceeds the timeout" do
      expect { tool.call(name: "sleep", arguments: ["10"], timeout: 0.1) }.to raise_error(
        RuntimeError,
        "command timed out after 0.1s"
      )
    end

    context "when given arguments" do
      before do
        allow(command).to receive(:env).and_return(command)
        allow(command).to receive(:argv).and_return(command)
        allow(command).to receive(:spawn).and_return(command)
        allow(command).to receive(:limit).and_return(command)
        allow(LLM::Tool::Exec::Command).to receive(:new).and_return(command)
        tool.call(name: "echo", arguments: ["hi"])
      end

      it "limits stdout and stderr by max_bytes" do
        expect(command).to have_received(:limit).with(
          stdout: LLM::Tool::Exec.max_bytes,
          stderr: LLM::Tool::Exec.max_bytes
        )
      end

      it "passes the arguments to the command" do
        expect(command).to have_received(:argv).with("hi")
      end

      it "passes an empty env by default" do
        expect(command).to have_received(:env).with({})
      end

      it "returns the command output" do
        expect(tool.call(name: "echo", arguments: ["hi"])).to eq(
          ok: true, stdout: "hi\n", stderr: ""
        )
      end
    end

    context "when constructed with env" do
      before do
        allow(command).to receive(:env).and_return(command)
        allow(command).to receive(:argv).and_return(command)
        allow(command).to receive(:spawn).and_return(command)
        allow(command).to receive(:limit).and_return(command)
        allow(LLM::Tool::Exec::Command).to receive(:new).and_return(command)
        described_class.new(env: {"FOO" => "bar"}).call(name: "echo", arguments: ["hi"])
      end

      it "passes the env to the command" do
        expect(command).to have_received(:env).with({"FOO" => "bar"})
      end
    end
  end

  describe "when spawning a real command" do
    let(:name) { "echo" }
    let(:arguments) { [] }
    let(:result) { tool.call(name:, arguments:) }

    before do
      skip "#{name} is not on the PATH" unless command_available?(name)
    end

    context "given echo" do
      let(:arguments) { ["hello world"] }

      it "captures fixed stdout" do
        expect(result).to eq(ok: true, stdout: "hello world\n", stderr: "")
      end
    end

    context "given printf" do
      let(:name) { "printf" }
      let(:arguments) { ["no-newline"] }

      it "captures fixed stdout" do
        expect(result[:stdout]).to eq("no-newline")
      end

      it "returns an empty stderr" do
        expect(result[:stderr]).to eq("")
      end
    end

    context "given sh" do
      let(:name) { "sh" }
      let(:arguments) { ["-c", "echo oops >&2"] }

      it "captures fixed stderr" do
        expect(result).to eq(ok: true, stdout: "", stderr: "oops\n")
      end
    end

    context "given false" do
      let(:name) { "false" }

      it "reports a failing command" do
        expect(result[:ok]).to be(false)
      end

      it "returns an empty stdout" do
        expect(result[:stdout]).to eq("")
      end
    end

    context "when given env" do
      let(:tool) { described_class.new(env: {"EXEC_SPEC_FOO" => "bar"}) }
      let(:name) { "sh" }
      let(:arguments) { ["-c", "printf %s \"$EXEC_SPEC_FOO\""] }

      it "sets environment for the spawned command" do
        expect(result).to eq(ok: true, stdout: "bar", stderr: "")
      end
    end

    context "when given a byte limit" do
      let(:name) { "ruby" }
      let(:arguments) { ["-e", "STDOUT.write('x' * 1000)"] }
      let(:result) { tool.call(name:, arguments:, max_bytes: 16) }

      it "caps stdout at max_bytes" do
        expect(result[:stdout]).to eq("x" * 16)
      end

      it "returns an empty stderr" do
        expect(result[:stderr]).to eq("")
      end
    end
  end

  ##
  # True when the given executable is present on the PATH.
  def command_available?(name)
    (ENV["PATH"] || "").split(File::PATH_SEPARATOR).any? do |dir|
      File.executable?(File.join(dir, name))
    end
  end
end
