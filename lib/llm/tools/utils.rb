# frozen_string_literal: true

class LLM::Tool
  ##
  # Shared utilities for tool implementations.
  module Utils
    ##
    # Truncates a string so a tool return stays bounded.
    # Appends a marker when truncated so the model knows
    # more content was available.
    # @param [String] content
    # @param [Integer] max_chars
    #  The max number of characters to keep
    # @return [String]
    def truncate(content, max_chars:)
      return content if content.to_s.length <= max_chars
      "#{content.to_s[0, max_chars]}\n...\n[truncated: more than #{max_chars} chars]"
    end

    ##
    # Wait for a command to finish, or abort
    # with an error when it exceeds the
    # specified timeout.
    # @param [Test::Command] command
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
