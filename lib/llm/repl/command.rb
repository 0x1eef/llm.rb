# frozen_string_literal: true

class LLM::Repl
  ##
  # The {LLM::Repl::Command LLM::Repl::Command} class is the superclass
  # of all read-eval-print loop commands. A command has a name, and a
  # description. This basic version does not implement parameters. A
  # command is accessible via the `/` prefix: eg `/exit`.
  class Command
    UNDEFINED = Object.new
    private_constant :UNDEFINED

    ##
    # @api private
    Parameter = Struct.new(:name, :type, :description, :options, :index, :value) do
      ##
      # @return [Boolean]
      def required?
        options[:required] == true
      end

      ##
      # Mark the parameter as required
      # @return [void]
      def required!
        options[:required] = true
      end

      ##
      # @return [Boolean]
      def optional?
        not required?
      end

      ##
      # Assign a parameter value - with type checks
      # @param [String] other
      # @return [void]
      def value=(other)
        raise TypeError, "#{other.class} is not a #{type}" unless type === other
        self[:value] = other
      end
    end

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
    def self.find_by(input: UNDEFINED, name: UNDEFINED)
      if input != UNDEFINED
        return nil unless input[0] == "/"
        n, = input.split(" ")
        registry.find { n[1..] == _1.name }
      elsif name != UNDEFINED
        registry.find { name == _1.name }
      else
        raise ArgumentError, "provide either an input or a name"
      end
    end

    ##
    # @param [LLM::Repl::Command] command
    #  A new subclass
    # @return [void]
    def self.inherited(command)
      LLM.lock(:inherited) do
        registry << command
        command.instance_variable_set(:@parameters, {})
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
    # @param [Symbol] name
    # @param [Class] type
    # @param [String] description
    # @param [Hash] options
    # @return [void]
    def self.parameter(name, type, description, options = {})
      @parameters[name] = Parameter.new(
        name, type,
        description, options,
        @parameters.size, nil
      )
    end

    ##
    # @return [Hash]
    def self.parameters
      @parameters
    end

    ##
    # @param [Array<Symbol>] names
    #  One or more required names
    # @return [void]
    def self.required(names)
      names.each do |name|
        if @parameters.key?(name)
          @parameters[name].required!
        else
          raise LLM::Error, "'#{name}' is not a known parameter"
        end
      end
    end

    ##
    # @param [LLM::Repl] repl
    # @return [LLM::Repl::Command]
    def initialize(repl)
      @repl = repl
    end

    ##
    # Write a string to the transcript
    # @param [String] str
    # @return [void]
    def write(str, who: "command(#{self.class.name}): ")
      @repl.write(who, Curses::A_BOLD)
      @repl.write(str)
    end

    ##
    # This method should be implemented by subclasses.
    # @raise [NotImplementedError]
    def call(...)
      raise NotImplementedError, "#{self.class}#call is not implemented"
    end

    ##
    # @return [Hash<Symbol, Parameter>]
    def parameters
      self.class.parameters
    end

    ##
    # @return [Hash]
    def to_h
      parameters.transform_values(&:value)
    end
    require_relative "commands/exit"
  end
end

##
# Convenience constant
LLM::Command = LLM::Repl::Command
