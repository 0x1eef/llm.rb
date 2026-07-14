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
    # Find a command by a name, or by an input string.
    # @example find by name
    #  LLM::Repl::Command.find_by(name: "exit")
    # @example find by input string
    #  LLM::Repl::Command.find_by(input: "/exit")
    # @note
    #  The input string must be prefixed with "/"
    #  or it won't be matched. The match is made
    #  against the string before the first space -
    #  so "/exit foo" will match the "exit" command
    #  but "/exitnow" will not.
    # @param [String] input
    # @param [String] name
    # @return [LLM::Repl::Command, nil]
    def self.find_by(input: nil, name: nil)
      if input
        return nil unless input[0] == "/"
        n, = input.split(" ")
        registry.find { n[1..] == _1.name }
      elsif name
        registry.find { name == _1.name }
      else
        raise ArgumentError, "provide one of: input, name"
      end
    end

    ##
    # @param [LLM::Repl::Command] command
    #  A new subclass
    # @return [void]
    def self.inherited(command)
      LLM.lock(:inherited) do
        registry << command
      end
    end

    ##
    # @return [Array<LLM::Repl::Command]
    def self.registry
      @registry ||= []
    end

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
