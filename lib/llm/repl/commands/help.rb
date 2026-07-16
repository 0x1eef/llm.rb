# frozen_string_literal: true

class LLM::Repl
  class Help < Command
    name "help"
    description "show help for a given command"
    parameter :name, String, "The name of a command"

    ##
    # @param [String] name
    # @return [void]
    def call(name: nil)
      if name.nil?
        write("\n#{self.class.help}\n\n")
      elsif command = LLM::Command.find_by(name:)
        write("\n#{command.help}\n\n")
      else
        write "\nNo help for #{name} was found" \
              "\nThat command doesn't exist." \
              "\n\n"
      end
    end
  end
end
