# frozen_string_literal: true

class LLM::Alibaba
  ##
  # Alibaba Model Studio is OpenAI-compatible, so it reuses OpenAI's
  # request adaptation. It only overrides schema handling, which falls
  # back to `json_object` — Alibaba does not support `json_schema`.
  # @api private
  module RequestAdapter
    require_relative "../openai/schema"
    include LLM::OpenAI::Schema
  end
end
