# frozen_string_literal: true

module LLM
  ##
  # LangSmith-specific tracer built on top of Telemetry.
  #
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   llm.tracer = LLM::Tracer::Langsmith.new(
  #     llm,
  #     session_id: "123e4567-e89b-12d3-a456-426614174000",
  #     metadata: {env: "dev"},
  #     tags: ["changelog"]
  #   )
  class Tracer::Langsmith < Tracer::Telemetry
    UUID = /\A
      [0-9a-f]{8}-
      [0-9a-f]{4}-
      [1-5][0-9a-f]{3}-
      [89ab][0-9a-f]{3}-
      [0-9a-f]{12}
    \z/ix

    def initialize(provider, options = {})
      super
      setup_langsmith!(options)
    end

    private

    def trace_attributes(span_kind:)
      attributes = {}
      session_id = thread[thread_langsmith_session_id_key]
      metadata = thread[thread_langsmith_metadata_key] || {}
      tags = thread[thread_langsmith_tags_key] || []

      unless session_id.to_s.empty?
        attributes["langsmith.trace.session_id"] = session_id
      end
      metadata.each do |key, value|
        next if value.nil?

        attributes["langsmith.metadata.#{key}"] = serialize_langsmith_value(value)
      end
      unless tags.empty?
        attributes["langsmith.span.tags"] = tags.map(&:to_s).join(",")
      end
      attributes["langsmith.span.kind"] = span_kind
      attributes
    end

    def setup_langsmith!(options)
      options ||= {}
      metadata = options[:metadata] || {}
      session_id = normalize_langsmith_session_id(
        options[:session_id],
        metadata:
      )
      thread[thread_langsmith_metadata_key] = metadata
      thread[thread_langsmith_session_id_key] = session_id
      thread[thread_langsmith_tags_key] = options[:tags] || []
    end

    def serialize_langsmith_value(value)
      case value
      when String, Numeric, TrueClass, FalseClass
        value
      else
        LLM.json.dump(value)
      end
    end

    def normalize_langsmith_session_id(session_id, metadata:)
      raw = session_id&.to_s
      return nil if raw.to_s.empty?
      return raw if uuid?(raw)

      # Keep arbitrary identifiers in metadata instead of forcing
      # them into langsmith.trace.session_id, which expects a UUID.
      metadata[:session_id] ||= raw
      nil
    end

    def uuid?(value)
      value.match?(UUID)
    end

    def thread_langsmith_metadata_key
      @thread_langsmith_metadata_key ||= :"llm.langsmith.metadata.#{object_id}"
    end

    def thread_langsmith_session_id_key
      @thread_langsmith_session_id_key ||= :"llm.langsmith.session_id.#{object_id}"
    end

    def thread_langsmith_tags_key
      @thread_langsmith_tags_key ||= :"llm.langsmith.tags.#{object_id}"
    end
  end
end
