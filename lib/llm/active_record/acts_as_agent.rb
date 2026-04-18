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
        options = model.llm_agent_options
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
    # @return [void]
    def acts_as_agent(options = EMPTY_HASH)
      options = DEFAULTS.merge(options)
      usage_columns = DEFAULT_USAGE_COLUMNS.merge(options[:usage_columns] || EMPTY_HASH)
      class_attribute :llm_agent_options, instance_accessor: false, default: DEFAULTS unless respond_to?(:llm_agent_options)
      self.llm_agent_options = options.merge(usage_columns: usage_columns.freeze).freeze
      extend Hooks
    end

    module InstanceMethods
      private

      ##
      # Returns the resolved provider instance for this record.
      # @return [LLM::Provider]
      def llm
        options = self.class.llm_agent_options
        provider = self[columns[:provider_column]]
        kwargs = resolve_options(options[:provider])
        @llm ||= LLM.method(provider).call(**kwargs)
        @llm.tracer = resolve_option(options[:tracer]) if options[:tracer]
        @llm
      end

      ##
      # @return [LLM::Agent]
      def ctx
        @ctx ||= begin
          options = self.class.llm_agent_options
          params = resolve_options(options[:context]).dup
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

      ##
      # @return [void]
      def flush
        attrs = {
          columns[:data_column] => serialize_context(self.class.llm_agent_options[:format]),
          columns[:input_tokens] => ctx.usage.input_tokens,
          columns[:output_tokens] => ctx.usage.output_tokens,
          columns[:total_tokens] => ctx.usage.total_tokens
        }
        assign_attributes(attrs)
        save!
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
        else EMPTY_HASH.dup
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
          options = self.class.llm_agent_options
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
end

::ActiveRecord::Base.extend(LLM::ActiveRecord::ActsAsAgent)
