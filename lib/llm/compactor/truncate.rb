# frozen_string_literal: true

class LLM::Compactor
  ##
  # An {LLM::Compactor::Truncate LLM::Compactor::Truncate}
  # drops the oldest messages when the conversation grows
  # beyond a configured size, keeping only the N most recent
  # messages.
  #
  # No LLM call is made but this strategy is purely lossy. It
  # also fast - no network required and operates purely on
  # memory.
  class Truncate < self
    ##
    # @param [Integer] keep
    #  The last n number of messages to keep
    # @return [Array<LLM::Message>, nil]
    def call(keep: 64)
      if keep > messages.reject(&:system?).size
        nil
      else
        stream.on_compaction(ctx, self)
        kept = messages.last(keep)
        messages.replace([messages.select(&:system?).first, *kept].compact)
        ctx.compacted = true
        stream.on_compaction_finish(ctx, self)
        kept
      end
    end
  end
end
