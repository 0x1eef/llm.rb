# frozen_string_literal: true

module LLM::ActiveRecord
  ##
  # ActiveRecord integration for persisting {LLM::Agent LLM::Agent} state.
  #
  # This wrapper reuses the same record-backed runtime surface as
  # {LLM::ActiveRecord::ActsAsLLM}, but builds an {LLM::Agent LLM::Agent}
  # instead of an {LLM::Context LLM::Context}. Agent defaults such as model,
  # tools, schema, instructions, and concurrency are configured on the model
  # class and forwarded to an internal agent subclass.
  module ActsAsAgent
    EMPTY_HASH = LLM::ActiveRecord::ActsAsLLM::EMPTY_HASH
    DEFAULT_USAGE_COLUMNS = LLM::ActiveRecord::ActsAsLLM::DEFAULT_USAGE_COLUMNS
    DEFAULTS = LLM::ActiveRecord::ActsAsLLM::DEFAULTS
    Utils = LLM::ActiveRecord::ActsAsLLM::Utils

    module ClassMethods
      def model(model = nil)
        return agent.model if model.nil?
        agent.model(model)
      end

      def tools(*tools)
        return agent.tools if tools.empty?
        agent.tools(*tools)
      end

      def schema(schema = nil)
        return agent.schema if schema.nil?
        agent.schema(schema)
      end

      def instructions(instructions = nil)
        return agent.instructions if instructions.nil?
        agent.instructions(instructions)
      end

      def concurrency(concurrency = nil)
        return agent.concurrency if concurrency.nil?
        agent.concurrency(concurrency)
      end

      def agent
        @agent ||= Class.new(LLM::Agent)
      end
    end

    module Hooks
      ##
      # Called when hooks are extended onto an ActiveRecord model.
      #
      # @param [Class] model
      # @return [void]
      def self.extended(model)
        options = model.llm_plugin_options
        model.validates options[:provider_column], options[:model_column], presence: true
        model.include LLM::ActiveRecord::ActsAsLLM::InstanceMethods unless model.ancestors.include?(LLM::ActiveRecord::ActsAsLLM::InstanceMethods)
        model.include InstanceMethods unless model.ancestors.include?(InstanceMethods)
        model.extend ClassMethods unless model.singleton_class.ancestors.include?(ClassMethods)
      end
    end

    ##
    # Installs the `acts_as_agent` wrapper on an ActiveRecord model.
    #
    # @param [Hash] options
    # @option options [Symbol] :format
    #   Storage format for the serialized agent state. Use `:string` for text
    #   columns, or `:json` / `:jsonb` for structured JSON columns with
    #   ActiveRecord JSON typecasting enabled.
    # @option options [Proc, Symbol, LLM::Tracer, nil] :tracer
    #   Optional tracer, method name, or proc that resolves to one and is
    #   assigned through `llm.tracer = ...` on the resolved provider.
    # @yield
    #   Evaluated in the model class after the wrapper is installed, so agent
    #   DSL methods such as `model`, `tools`, `schema`, `instructions`, and
    #   `concurrency` can be configured inline.
    # @return [void]
    def acts_as_agent(options = EMPTY_HASH, &block)
      options = DEFAULTS.merge(options)
      usage_columns = DEFAULT_USAGE_COLUMNS.merge(options[:usage_columns] || EMPTY_HASH)
      class_attribute :llm_plugin_options, instance_accessor: false, default: DEFAULTS unless respond_to?(:llm_plugin_options)
      self.llm_plugin_options = options.merge(usage_columns: usage_columns.freeze).freeze
      extend Hooks
      class_exec(&block) if block
    end

    module InstanceMethods
      ##
      # Returns the resolved provider instance for this record.
      # @return [LLM::Provider]
      def llm
        options = self.class.llm_plugin_options
        columns = Utils.columns(options)
        provider = self[columns[:provider_column]]
        kwargs = Utils.resolve_options(self, options[:provider], ActsAsAgent::EMPTY_HASH)
        return @llm if @llm
        @llm = LLM.method(provider).call(**kwargs)
        @llm.tracer = Utils.resolve_option(self, options[:tracer]) if options[:tracer]
        @llm
      end

      private

      ##
      # @return [LLM::Agent]
      def ctx
        @ctx ||= begin
          options = self.class.llm_plugin_options
          columns = Utils.columns(options)
          params = Utils.resolve_options(self, options[:context], ActsAsAgent::EMPTY_HASH).dup
          params[:model] ||= self[columns[:model_column]]
          ctx = self.class.agent.new(llm, params.compact)
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

::ActiveRecord::Base.extend(LLM::ActiveRecord::ActsAsAgent)
