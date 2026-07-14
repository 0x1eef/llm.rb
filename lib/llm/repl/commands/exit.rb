# frozen_string_literal: true

class LLM::Repl
  ##
  # The 'exit' command exits the read-eval-print loop
  # by throwing. The {LLM::Repl LLM::Repl} class covers
  # the loop with a catch that gracefully recovers and
  # exits the loop.
  class Command::Exit < Command
    name "exit"
    description "exits the repl"

    ##
    # @return [void]
    def call
      throw(:exit)
    end
  end
end
