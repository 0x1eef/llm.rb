# frozen_string_literal: true

class LLM::Alibaba
  ##
  # Handles non-2XX responses from Alibaba Cloud Model Studio.
  #
  # Falls back to the OpenAI-compatible error handling for
  # everything except Alibaba's `insufficient_quota`, which
  # is raised as its own {LLM::InsufficientQuotaError} (a quota
  # issue, not a transient rate limit, so it is not retried).
  # @api private
  class ErrorHandler < LLM::OpenAI::ErrorHandler
    private

    ##
    # @return [LLM::Error]
    def error
      if quota_error?
        LLM::InsufficientQuotaError.new("Insufficient quota").tap { _1.response = res }
      else
        super
      end
    end

    ##
    # Alibaba returns `type: "insufficient_quota"` (with the
    # same `code`) when the account's quota is exhausted.
    # @return [Boolean]
    def quota_error?
      error = body["error"] || {}
      error["type"] == "insufficient_quota" || error["code"] == "insufficient_quota"
    end
  end
end
