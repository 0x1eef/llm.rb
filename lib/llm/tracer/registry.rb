# frozen_string_literal: true

class LLM::Tracer
  ##
  # {LLM::Tracer::Registry LLM::Tracer::Registry} counts the scopes that
  # are open for each tracer.
  #
  # The count belongs to the tracer, not to the thread that opened a
  # scope. A tool runs on a thread of its own and opens a scope there for
  # the turn's tracer, and a count kept per thread would let that scope
  # look like the outermost one: it would end the tracer while the turn
  # is still running, and every write after it would fail.
  #
  # @api private
  class Registry
    ##
    # @return [LLM::Tracer::Registry]
    def initialize
      @counts = ObjectSpace::WeakMap.new
      @mutex  = Mutex.new
    end

    ##
    # Records that a scope was opened for a tracer.
    # @param [LLM::Tracer] tracer
    # @return [LLM::Tracer::Registry]
    #  Returns self, so a caller can tell the scope was recorded
    def enter(tracer)
      @mutex.synchronize do
        @counts[tracer] = count(tracer) + 1
      end
      self
    end

    ##
    # Records that a scope was closed, and tells the tracer it is
    # finished when it was the last one that was open.
    #
    # The count is brought up to date under the lock, and the tracer is
    # told after the lock is released: a tracer that calls back into the
    # provider from `on_exit` would otherwise deadlock against itself.
    #
    # An `exit` without a matching `enter` is clamped at zero rather than
    # allowed to take the count negative.
    # @param [LLM::Tracer] tracer
    # @return [void]
    def exit(tracer)
      last = @mutex.synchronize do
        remaining = count(tracer) - 1
        remaining = 0 if remaining < 0
        if remaining.zero?
          forget(tracer)
          true
        else
          @counts[tracer] = remaining
          false
        end
      end
      tracer.on_exit if last
    end

    private

    ##
    # Drops a tracer that has no open scopes left.
    # @param [LLM::Tracer] tracer
    # @return [Boolean]
    def forget(tracer)
      if @counts.respond_to?(:delete)
        @counts.delete(tracer)
      else
        @counts[tracer] = 0
      end
      true
    end

    ##
    # @param [LLM::Tracer] tracer
    # @return [Integer]
    def count(tracer)
      @counts[tracer] || 0
    end
  end
end
