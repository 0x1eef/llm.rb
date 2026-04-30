# frozen_string_literal: true

module LLM::ActiveRecord
  ##
  # ActiveRecord integration for persisting {LLM::Context LLM::Context} state.
  #
  # This wrapper maps model columns onto provider selection, model selection,
  # usage accounting, and serialized context data while leaving application-
  # specific concerns such as credentials, associations, and UI shaping to
  # the host app.
  #
  # Context state can be stored as a JSON string (`format: :string`, the
  # default) or as a structured object (`format: :json` / `:jsonb`) for
  # databases such as PostgreSQL that can persist JSON natively.
  # `:json` and `:jsonb` expect a real JSON column type with ActiveRecord
  # handling JSON typecasting for the model. `provider:`, `context:`, and
  # `tracer:` can also be configured as symbols that are called on the model.
  module ActsAsLLM
    EMPTY_HASH = {}.freeze
    DEFAULTS = {
      data_column: :data,
      format: :string,
      tracer: nil,
      provider: nil,
      context: EMPTY_HASH
    }.freeze

    ##
    # Shared helper methods for the ORM wrapper.
    #
    # These utilities keep persistence plumbing out of the wrapped model's
    # method namespace so the injected surface stays focused on the runtime
    # API itself.
    # @api private
    module Utils
      ##
      # Resolves a single configured option against a model instance.
      # @return [Object]
      def self.resolve_option(obj, option)
        case option
        when Proc then obj.instance_exec(&option)
        when Symbol then obj.send(option)
        when Hash then option.dup
        else option
        end
      end

      ##
      # Resolves hash-like wrapper options against a model instance.
      # @return [Hash]
      def self.resolve_options(obj, option, empty_hash)
        case option
        when Proc, Symbol, Hash then resolve_option(obj, option)
        else empty_hash.dup
        end
      end

      ##
      # Serializes the runtime into the configured storage format.
      # @return [String, Hash]
      def self.serialize_context(ctx, format)
        case format
        when :string then ctx.to_json
        when :json, :jsonb then ctx.to_h
        else raise ArgumentError, "Unknown format: #{format.inspect}"
        end
      end

      ##
      # Maps wrapper options onto the record's storage columns.
      # @return [Hash]
      def self.columns(options)
        {
          data_column: options[:data_column]
        }.freeze
      end

      ##
      # Resolves the provider runtime for a record.
      # @return [LLM::Provider]
      def self.resolve_provider(obj, options, empty_hash)
        provider = resolve_option(obj, options[:provider])
        return provider if LLM::Provider === provider
        raise ArgumentError, "provider: must resolve to an LLM::Provider instance"
      end

      ##
      # Persists the runtime state and usage columns back onto the record.
      # @return [void]
      def self.save(obj, ctx, options)
        columns = self.columns(options)
        obj.assign_attributes(columns[:data_column] => serialize_context(ctx, options[:format]))
        obj.save!
      end
    end

    module Hooks
      ##
      # Called when hooks are extended onto an ActiveRecord model.
      #
      # @param [Class] model
      # @return [void]
      def self.extended(model)
        model.include InstanceMethods unless model.ancestors.include?(InstanceMethods)
      end
    end

    ##
    # Installs the `acts_as_llm` wrapper on an ActiveRecord model.
    #
    # @param [Hash] options
    # @option options [Symbol] :format
    #   Storage format for the serialized context. Use `:string` for text
    #   columns, or `:json` / `:jsonb` for structured JSON columns with
    #   ActiveRecord JSON typecasting enabled.
    # @option options [Proc, Symbol, LLM::Tracer, nil] :tracer
    #   Optional tracer, method name, or proc that resolves to one and is
    #   assigned through `llm.tracer = ...` on the resolved provider.
    # @option options [Proc, Symbol, LLM::Provider] :provider
    #   Must resolve to an `LLM::Provider` instance for the current record.
    # @return [void]
    def acts_as_llm(options = EMPTY_HASH)
      options = DEFAULTS.merge(options)
      class_attribute :llm_plugin_options, instance_accessor: false, default: DEFAULTS unless respond_to?(:llm_plugin_options)
      self.llm_plugin_options = options.freeze
      extend Hooks
    end

    module InstanceMethods
      ##
      # Continues the stored context with new input and flushes it.
      # @see LLM::Context#talk
      # @return [LLM::Response]
      def talk(...)
        options = self.class.llm_plugin_options
        ctx.talk(...).tap { Utils.save(self, ctx, options) }
      end

      ##
      # Continues the stored context through the Responses API and flushes it.
      # @see LLM::Context#respond
      # @return [LLM::Response]
      def respond(...)
        options = self.class.llm_plugin_options
        ctx.respond(...).tap { Utils.save(self, ctx, options) }
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
      # @note The bang keeps the ActiveRecord and Sequel wrappers aligned.
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
        ctx.usage || LLM::Object.from(input_tokens: 0, output_tokens: 0, total_tokens: 0)
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
        return @llm if @llm
        @llm = Utils.resolve_provider(self, options, ActsAsLLM::EMPTY_HASH)
        @llm.tracer = Utils.resolve_option(self, options[:tracer]) if options[:tracer]
        @llm
      end

      private

      ##
      # @return [LLM::Context]
      def ctx
        @ctx ||= begin
          options = self.class.llm_plugin_options
          columns = Utils.columns(options)
          params = Utils.resolve_options(self, options[:context], ActsAsLLM::EMPTY_HASH).dup
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
    end
  end
end

::ActiveRecord::Base.extend(LLM::ActiveRecord::ActsAsLLM)
