# frozen_string_literal: true

module LLM
  ##
  # {LLM::Skill LLM::Skill} represents a directory-backed packaged capability.
  # A skill directory must contain a `SKILL.md` file with YAML frontmatter.
  # Skills can expose themselves as normal {LLM::Tool LLM::Tool} classes through
  # {#to_tool}. This keeps skills on the same execution path as local tools.
  class Skill
    ##
    # Load a skill from a directory.
    # @param [String, Pathname] path
    # @return [LLM::Skill]
    def self.load(path)
      new(path).tap(&:load!)
    end

    ##
    # Returns the skill directory.
    # @return [String]
    attr_reader :path

    ##
    # Returns the skill name.
    # @return [String]
    attr_reader :name

    ##
    # Returns the skill description.
    # @return [String]
    attr_reader :description

    ##
    # Returns the skill instructions.
    # @return [String]
    attr_reader :instructions

    ##
    # Returns the skill frontmatter.
    # @return [LLM::Object]
    attr_reader :frontmatter

    ##
    # Returns the skill tools.
    # @return [Array<Class<LLM::Tool>>]
    attr_reader :tools

    ##
    # @param [String] path
    #  The path to a directory
    # @return [LLM::Skill]
    def initialize(path)
      @path = path.to_s
      @name = ::File.basename(@path)
      @description = "Skill: #{@name}"
      @instructions = ""
      @frontmatter = LLM::Object.from({})
      @tools = []
      @inherit_tools = false
    end

    ##
    # Load and parse the skill.
    # @return [LLM::Skill]
    def load!
      path = ::File.join(@path, "SKILL.md")
      parse(::File.read(path))
      self
    end

    ##
    # Execute the skill by wrapping it in a small agent with the skill
    # instructions. The context is bound explicitly by the caller so the
    # nested agent can inherit context-level behavior such as streaming.
    # @param [LLM::Context] ctx
    # @return [Hash]
    def call(ctx)
      content = agent(ctx).talk("Solve the user's query.").content
      {content:}
    end

    ##
    # Expose the skill as a normal LLM::Tool. The context is bound explicitly
    # when the tool class is built.
    # @param [LLM::Context] ctx
    # @return [Class<LLM::Tool>]
    def to_tool(ctx)
      skill = self
      Class.new(LLM::Tool) do
        attr_accessor :tracer

        name skill.name
        description skill.description

        define_singleton_method(:skill?) do
          true
        end

        define_method(:call) do
          skill.call(ctx)
        end
      end
    end

    ##
    # Returns true when a skill should inherit tools from its parent
    # @return [Boolean]
    def inherit_tools?
      @inherit_tools
    end

    private

    def messages_for(ctx)
      messages = ctx.messages
        .to_a
        .select { _1.user? || _1.assistant? }
        .reject { _1.tool_call? || _1.tool_return? }
        .last(8)
      return messages if messages.empty?
      [LLM::Message.new(:user, "Recent context:"), *messages]
    end

    def parse(content)
      match = content.match(/\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m)
      unless match
        @instructions = content
        return
      end
      require "yaml" unless defined?(::YAML)
      @frontmatter = LLM::Object.from(YAML.safe_load(match[1]) || {})
      @name = @frontmatter.name || @name
      @description = @frontmatter.description || @description
      @instructions = match[2]
      @inherit_tools, @tools = parse_tools(@frontmatter.tools)
    end

    def parse_tools(tools)
      case tools
      when String
        tools == "inherit" ? [true, []] : raise_invalid_error!(tools)
      when Array
        [false, [*@frontmatter.tools].map { LLM::Tool.find_by_name!(_1) }]
      when NilClass
        [false, []]
      else
        raise_invalid_error!(tools)
      end
    end

    def raise_invalid_error!(tools)
      raise LLM::Error, "invalid value for tools key: '#{tools}'"
    end

    def agent(ctx)
      instructions, tools, tracer, inherit_tools = self.instructions, self.tools, ctx.llm.tracer, inherit_tools?
      params = ctx.params.merge(mode: ctx.mode).reject { [:tools, :schema].include?(_1) }
      concurrency = params[:stream].extra[:concurrency] if LLM::Stream === params[:stream]
      params[:concurrency] = concurrency if concurrency
      agent = Class.new(LLM::Agent) do
        instructions(instructions)
        tools(inherit_tools ? [*ctx.params[:tools]].reject(&:skill?) : tools)
        tracer(tracer)
      end.new(ctx.llm, params)
      agent.messages.concat(messages_for(ctx))
      agent
    end
  end
end
