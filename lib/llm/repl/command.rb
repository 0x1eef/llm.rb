# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Command LLM::Repl::Command} class is the superclass
  # of all read-eval-print loop commands. A command has a name, and a
  # description. This basic version does not implement parameters. A
  # command is accessible via the `/` prefix: eg `/exit`.
  class Command
    ##
    # @api private
    UNDEFINED = Object.new

    ##
    # Set or get a command name.
    # @param [String] name
    #  The command name.
    # @return [String]
    def self.name(name = UNDEFINED)
      return @name if name == UNDEFINED
      @name = name
    end

    ##
    # Set or get a command description.
    # @param [String] description
    #  The command description.
    # @return [String]
    def self.description(description = UNDEFINED)
      return @description if description == UNDEFINED
      @description = description
    end

    ##
    # This method should be implemented by subclasses.
    # @raise [NotImplementedError]
    def call(...)
      raise NotImplementedError, "#{self.class}#call is not implemented"
    end
    require_relative "commands/exit"
  end
end
