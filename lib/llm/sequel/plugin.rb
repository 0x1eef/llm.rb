# frozen_string_literal: true

module LLM::Sequel
  ##
  # Sequel plugin for persisting {LLM::Context LLM::Context} state.
  #
  # This plugin maps model columns onto provider selection, model
  # selection, usage accounting, and serialized context data while
  # leaving application-specific concerns such as credentials,
  # associations, and UI shaping to the host app.
  #
  # Context state can be stored as a JSON string (`format: :string`, the
  # default) or as a structured object (`format: :json` / `:jsonb`) for
  # databases such as PostgreSQL that can persist JSON natively.
  # `:json` and `:jsonb` expect a real JSON column type with Sequel handling
  # JSON typecasting for the model. `provider:`, `context:`, and `tracer:`
  # can also be configured as symbols that are called on the model.
  module Plugin
    EMPTY_HASH = {}.freeze
    DEFAULT_USAGE_COLUMNS = {
      input_tokens: :input_tokens,
      output_tokens: :output_tokens,
      total_tokens: :total_tokens
    }.freeze
    DEFAULTS = {
      provider_column: :provider,
      model_column: :model,
      data_column: :data,
      format: :string,
      usage_columns: DEFAULT_USAGE_COLUMNS,
      tracer: nil,
      provider: EMPTY_HASH,
      context: EMPTY_HASH
    }.freeze

    ##
    # Called by Sequel when the plugin is first applied to a model class.
    #
    # This hook installs the plugin's class- and instance-level behavior on
    # the target model. It runs before {configure}, so it should only attach
    # methods and not depend on per-model plugin options.
    #
    # @param [Class] model
    # @return [void]
    def self.apply(model, **)
      model.extend ClassMethods
      model.include InstanceMethods
    end

    ##
    # Called by Sequel after {apply} with the options passed to
    # `plugin :llm, ...`.
    #
    # This hook merges plugin defaults with the model's explicit settings and
    # stores the resolved configuration on the model class for later use by
    # instance methods such as {InstanceMethods#llm} and {InstanceMethods#ctx}.
    #
    # @param [Class] model
    # @param [Hash] options
    # @option options [Symbol] :format
    #   Storage format for the serialized context. Use `:string` for text
    #   columns, or `:json` / `:jsonb` for structured JSON columns with Sequel
    #   JSON typecasting enabled.
    # @option options [Proc, Symbol, LLM::Tracer, nil] :tracer
    #   Optional tracer, method name, or proc that resolves to one and is
    #   assigned through `llm.tracer = ...` on the resolved provider.
    # @return [void]
    def self.configure(model, options = EMPTY_HASH)
      options = DEFAULTS.merge(options)
      usage_columns = DEFAULT_USAGE_COLUMNS.merge(options[:usage_columns] || EMPTY_HASH)
      model.instance_variable_set(
        :@llm_plugin_options,
        options.merge(usage_columns: usage_columns.freeze).freeze
      )
    end
  end

  module Plugin::ClassMethods
    ##
    # @return [Hash]
    def llm_plugin_options
      @llm_plugin_options || Plugin::DEFAULTS
    end
  end

  module Plugin::InstanceMethods
    ##
    # Continues the stored context with new input and flushes it.
    # @see LLM::Context#talk
    # @return [LLM::Response]
    def talk(...)
      ctx.talk(...).tap { flush }
    end

    ##
    # Continues the stored context through the Responses API and flushes it.
    # @see LLM::Context#respond
    # @return [LLM::Response]
    def respond(...)
      ctx.respond(...).tap { flush }
    end

    ##
    # Waits for queued tool work to finish.
    # @see LLM::Context#wait
    # @return [Array<LLM::Function::Return>]
    def wait(...)
      ctx.wait(...)
    end

    ##
    # Calls into the stored context.
    # @see LLM::Context#call
    # @return [Object]
    def call(...)
      ctx.call(...)
    end

    ##
    # @see LLM::Context#mode
    # @return [Symbol]
    def mode
      ctx.mode
    end

    ##
    # @see LLM::Context#messages
    # @return [Array<LLM::Message>]
    def messages
      ctx.messages
    end

    ##
    # @note The bang is used because Sequel reserves `model` for the
    #   underlying model class on instances.
    # @see LLM::Context#model
    # @return [String]
    def model!
      ctx.model
    end

    ##
    # @see LLM::Context#functions
    # @return [Array<LLM::Function>]
    def functions
      ctx.functions
    end

    ##
    # @see LLM::Context#returns
    # @return [Array<LLM::Function::Return>]
    def returns
      ctx.returns
    end

    ##
    # @see LLM::Context#cost
    # @return [LLM::Cost]
    def cost
      ctx.cost
    end

    ##
    # @see LLM::Context#context_window
    # @return [Integer]
    def context_window
      ctx.context_window
    rescue LLM::NoSuchModelError, LLM::NoSuchRegistryError
      0
    end

    ##
    # Returns usage from the mapped usage columns.
    # @return [LLM::Object]
    def usage
      LLM::Object.from(
        input_tokens: self[columns[:input_tokens]] || 0,
        output_tokens: self[columns[:output_tokens]] || 0,
        total_tokens: self[columns[:total_tokens]] || 0
      )
    end

    ##
    # @see LLM::Context#interrupt!
    # @return [nil]
    def interrupt!
      ctx.interrupt!
    end
    alias_method :cancel!, :interrupt!

    ##
    # @see LLM::Context#prompt
    # @return [LLM::Prompt]
    def prompt(&)
      ctx.prompt(&)
    end
    alias_method :build_prompt, :prompt

    ##
    # @see LLM::Context#image_url
    # @return [LLM::Object]
    def image_url(...)
      ctx.image_url(...)
    end

    ##
    # @see LLM::Context#local_file
    # @return [LLM::Object]
    def local_file(...)
      ctx.local_file(...)
    end

    ##
    # @see LLM::Context#remote_file
    # @return [LLM::Object]
    def remote_file(...)
      ctx.remote_file(...)
    end

    ##
    # @see LLM::Context#tracer
    # @return [LLM::Tracer]
    def tracer
      ctx.tracer
    end

    ##
    # Returns the resolved provider instance for this record.
    # @return [LLM::Provider]
    def llm
      options = self.class.llm_plugin_options
      provider = self[columns[:provider_column]]
      kwargs = resolve_options(options[:provider])
      return @llm if @llm
      @llm = LLM.method(provider).call(**kwargs)
      @llm.tracer = resolve_option(options[:tracer]) if options[:tracer]
      @llm
    end

    private

    ##
    # @return [LLM::Context]
    def ctx
      @ctx ||= begin
        options = self.class.llm_plugin_options
        params = resolve_options(options[:context]).dup
        params[:model] ||= self[columns[:model_column]]
        ctx = LLM::Context.new(llm, params.compact)
        data = self[columns[:data_column]]
        if data.nil? || data == ""
          ctx
        else
          case options[:format]
          when :string then ctx.restore(string: data)
          when :json, :jsonb then ctx.restore(data:)
          else raise ArgumentError, "Unknown format: #{options[:format].inspect}"
          end
        end
      end
    end

    ##
    # @return [void]
    def flush
      options = self.class.llm_plugin_options
      update({
        columns[:data_column] => serialize_context(options[:format]),
        columns[:input_tokens] => ctx.usage.input_tokens,
        columns[:output_tokens] => ctx.usage.output_tokens,
        columns[:total_tokens] => ctx.usage.total_tokens
      })
    end

    ##
    # @return [Hash]
    def resolve_option(option)
      case option
      when Proc then instance_exec(&option)
      when Symbol then send(option)
      when Hash then option.dup
      else option
      end
    end

    ##
    # @return [Hash]
    def resolve_options(option)
      case option
      when Proc, Hash then resolve_option(option)
      else Plugin::EMPTY_HASH.dup
      end
    end

    def serialize_context(format)
      case format
      when :string then ctx.to_json
      when :json, :jsonb then ctx.to_h
      else raise ArgumentError, "Unknown format: #{format.inspect}"
      end
    end

    def columns
      @columns ||= begin
        options = self.class.llm_plugin_options
        usage_columns = options[:usage_columns]
        {
          provider_column: options[:provider_column],
          model_column: options[:model_column],
          data_column: options[:data_column],
          input_tokens: usage_columns[:input_tokens],
          output_tokens: usage_columns[:output_tokens],
          total_tokens: usage_columns[:total_tokens]
        }.freeze
      end
    end
  end
end
