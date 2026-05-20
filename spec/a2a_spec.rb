# frozen_string_literal: true

require "setup"

RSpec.describe LLM::A2A do
  let(:transport_class) do
    Class.new do
      attr_reader :gets, :posts, :deletes, :streams

      def initialize(responses)
        @responses = responses
        @gets = []
        @posts = []
        @deletes = []
        @streams = []
      end

      def get(path)
        @gets << path
        @responses.fetch([:get, path])
      end

      def post(path, body)
        @posts << [path, body]
        @responses.fetch([:post, path])
      end

      def delete(path)
        @deletes << path
        @responses.fetch([:delete, path])
      end

      def get_stream(path)
        @streams << [:get, path]
        @responses.fetch([:get_stream, path], []).each { yield _1 }
      end

      def post_stream(path, body)
        @streams << [:post, path, body]
        @responses.fetch([:post_stream, path], []).each { yield _1 }
      end
    end
  end

  let(:responses) { {} }
  let(:transport) { transport_class.new(responses) }
  let(:a2a) { described_class.new(transport:, binding: :rest) }

  describe "#send_message" do
    let(:responses) do
      {
        [:post, "/message:send"] => {
          "task" => {"id" => "task_1"}
        }
      }
    end

    it "includes metadata when given" do
      a2a.send_message("hello", {}, metadata: {"tenant" => "acme"})
      expect(transport.posts.first.last[:metadata]).to eq("tenant" => "acme")
    end
  end

  describe "#card" do
    subject(:card) { a2a.card }

    let(:responses) do
      {
        [:get, "/.well-known/agent-card.json"] => {
          "name" => "Data Analyzer",
          "skills" => [
            {"id" => "analyze", "name" => "analyze", "description" => "Analyze data"}
          ],
          "signatures" => [
            {"protected" => "eyJhbGciOiJFZERTQSJ9", "signature" => "abc123"}
          ],
          "capabilities" => {
            "streaming" => true,
            "extensions" => [
              {"uri" => "https://example.com/extensions/history"}
            ]
          }
        }
      }
    end

    it "wraps signatures" do
      expect(card.signatures.first.signature).to eq("abc123")
    end

    it "wraps capability extensions" do
      expect(card.capabilities.extensions.first.uri).to eq("https://example.com/extensions/history")
    end
  end

  describe "#tasks" do
    subject(:tasks) { a2a.tasks }

    context "when getting a task" do
      let(:responses) do
        {
          [:get, "/tasks/task_1"] => {
            "id" => "task_1",
            "status" => {"state" => "TASK_STATE_COMPLETED"}
          }
        }
      end

      it "returns the task" do
        expect(tasks.get("task_1").id).to eq("task_1")
      end
    end

    context "when subscribing to a task" do
      let(:responses) do
        {
          [:get_stream, "/tasks/task_1:subscribe"] => [
            {"event" => "task", "taskId" => "task_1"}
          ]
        }
      end

      it "uses the task subscribe endpoint" do
        tasks.subscribe("task_1") { nil }
        expect(transport.streams).to eq([[:get, "/tasks/task_1:subscribe"]])
      end
    end

    context "when listing tasks" do
      let(:responses) do
        {
          [:get, "/tasks?contextId=ctx_1&status=completed&historyLength=10&statusTimestampAfter=2026-05-20T00%3A00%3A00Z&includeArtifacts=true&pageSize=5&pageToken=next"] => {
            "tasks" => []
          }
        }
      end

      it "includes the optional query params" do
        tasks.list(context_id: "ctx_1", status: "completed", history_length: 10,
                   status_timestamp_after: "2026-05-20T00:00:00Z",
                   include_artifacts: true, page_size: 5, page_token: "next")
        expect(transport.gets.first).to eq("/tasks?contextId=ctx_1&status=completed&historyLength=10&statusTimestampAfter=2026-05-20T00%3A00%3A00Z&includeArtifacts=true&pageSize=5&pageToken=next")
      end
    end

    context "when cancelling a task" do
      let(:responses) do
        {
          [:post, "/tasks/task_1:cancel"] => {
            "id" => "task_1"
          }
        }
      end

      it "includes metadata when given" do
        tasks.cancel("task_1", metadata: {"reason" => "user_request"})
        expect(transport.posts.first.last[:metadata]).to eq("reason" => "user_request")
      end
    end
  end

  describe "#notifications" do
    subject(:notifications) { a2a.notifications }

    let(:responses) do
      {
        [:get, "/tasks/task_1/pushNotificationConfigs"] => {
          "configs" => [
            {"id" => "cfg_1", "url" => "https://client.example.com/webhook"}
          ]
        }
      }
    end

    it "lists push notification configs" do
      expect(notifications.list("task_1").configs.first.id).to eq("cfg_1")
    end
  end

  describe "with a base path" do
    let(:responses) do
      {
        [:get, "/tenant-1/tasks/task_1"] => {
          "id" => "task_1"
        }
      }
    end

    let(:a2a) { described_class.new(transport:, binding: :rest, base_path: "/tenant-1") }

    it "prefixes REST task paths" do
      expect(a2a.tasks.get("task_1").id).to eq("task_1")
      expect(transport.gets.first).to eq("/tenant-1/tasks/task_1")
    end
  end
end
