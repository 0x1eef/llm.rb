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
    #  The last (approx) n number of messages to keep
    # @return [Array<LLM::Message>, nil]
    def call(keep: 64)
      if keep > messages.reject(&:system?).size
        nil
      else
        stream.on_compaction(self)
        kept = take(messages, keep)
        messages.replace([messages.select(&:system?).first, *kept].compact)
        ctx.compacted = true
        stream.on_compaction_finish(self)
        kept
      end
    end

    private

    def take(messages, limit)
      subset, in_tool_call = [], false
      messages.reverse_each.with_index(1) do |m, index|
        # We travel backwards - so we see a
        # tool return before we see a tool
        # call.
        #
        # When we see a tool return, our next
        # task is to find where it was called
        # from, and we will even override the
        # limit to do this.
        #
        # Otherwise, the conversation will become
        # corrupted and any attempt to use it will
        # be an API-level error.
        in_tool_call ||= m.tool_return?
        if index >= limit
          subset.unshift(m)
          in_tool_call ? next : break
        else
          subset.unshift(m)
        end
      end
      subset
    end
  end
end
