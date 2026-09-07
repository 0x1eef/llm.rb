# frozen_string_literal: true

require "setup"
require "tmpdir"
require "llm/tools/git"
require "llm/tools/exec"

RSpec.describe LLM::Tool::Git do
  let(:tool) { described_class.new }
  let(:dir) { Dir.mktmpdir("git-spec") }

  before do
    skip "git is not on the PATH" unless command_available?("git")
    Dir.chdir(dir) { make_repo! }
  end

  describe ".function" do
    let(:params) { described_class.function.params }

    it "defines the subcommand param" do
      expect(params.properties[:subcommand]).to be_a(LLM::Schema::String)
    end

    it "marks the subcommand param as required" do
      expect(params.properties[:subcommand]).to be_required
    end

    it "lists the git subcommands" do
      expect(params.properties[:subcommand].enum).to eq(%w[log diff commit checkout branch show])
    end
  end

  describe "when running a real command" do
    around do |example|
      Dir.chdir(dir) { example.call }
      FileUtils.rm_rf(dir)
    end

    it "lists branches" do
      res = tool.call(subcommand: "branch")
      expect(res).to eq(ok: true, stdout: "* main\n", stderr: "")
    end

    it "shows the log" do
      res = tool.call(subcommand: "log", arguments: ["--oneline"])
      expect(res[:ok]).to eq(true)
      expect(res[:stdout]).to match(/\A[0-9a-f]{7,40} initial\n\z/)
    end

    describe "when given a file to show" do
      let(:file) { File.join(dir, "file.txt") }

      before { tool.call(subcommand: "add", arguments: ["file.txt"]) }

      it "shows the file name in the commit" do
        res = tool.call(subcommand: "show", arguments: ["--oneline", "--name-only", "HEAD"])
        expect(res[:stdout]).to include("file.txt")
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

  ##
  # Create a dummy test repository
  def make_repo!
    system("git", "init", "-b", "main", out: File::NULL, err: File::NULL)
    system("git", "config", "user.email", "spec@example.com", out: File::NULL, err: File::NULL)
    system("git", "config", "user.name", "Spec", out: File::NULL, err: File::NULL)
    File.write("file.txt", "hello\n")
    system("git", "add", "file.txt", out: File::NULL, err: File::NULL)
    system("git", "commit", "-m", "initial", out: File::NULL, err: File::NULL)
  end
end
