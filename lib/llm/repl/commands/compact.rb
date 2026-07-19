# frozen_string_literal: true

class LLM::Repl
  ##
  # The 'compact' command frees space in the
  # context window and llm.rb is designed to
  # support multiple compaction strategies with
  # different trade offs. This command, though,
  # uses the 'truncate' strategy. See
  # {LLM::Compactor::Truncate LLM::Compactor::Truncate}
  # for more details.
  class Command::Compact < Command
    name "compact"
    description "frees space in the context window"

    ##
    # @return [void]
    def call
      write("compact in progress\n")
      compactor.call
      write("compact complete\n\n")
    end

    private

    ##
    # @return [LLM::Compactor::Truncate]
    def compactor
      @compactor ||= LLM::Compactor::Truncate.new(agent)
    end
  end
end
