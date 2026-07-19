# frozen_string_literal: true

class LLM::Tool
  ##
  # Shared utilities for tool implementations.
  module Utils
    ##
    # Wait for a command to finish, or abort
    # with an error when it exceeds the
    # specified timeout.
    # @param [Test::Cmd] command
    # @param [Integer] timeout
    # @return [void]
    def wait(command:, timeout:)
      start = now
      while command.running?
        if now - start > timeout
          command.kill!
          raise "command timed out after #{timeout}s"
        end
        sleep 0.01
      end
    end

    ##
    # @return [Numeric]
    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
