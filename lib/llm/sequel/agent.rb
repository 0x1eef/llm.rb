# frozen_string_literal: true

module LLM::Sequel
  ##
  # Sequel plugin for persisting {LLM::Agent LLM::Agent} state.
  #
  # This wrapper reuses the same record-backed runtime surface as
  # {LLM::Sequel::Plugin}, but builds an {LLM::Agent LLM::Agent} instead of an
  # {LLM::Context LLM::Context}. Agent defaults such as model, tools, schema,
  # instructions, and concurrency are configured on the model class and
  # forwarded to an internal agent subclass.
  module Agent
    EMPTY_HASH = LLM::Sequel::Plugin::EMPTY_HASH
    DEFAULT_USAGE_COLUMNS = LLM::Sequel::Plugin::DEFAULT_USAGE_COLUMNS
    DEFAULTS = LLM::Sequel::Plugin::DEFAULTS

    def self.apply(model, **)
      model.extend ClassMethods
      model.include LLM::Sequel::Plugin::InstanceMethods
      model.include InstanceMethods
    end

    def self.configure(model, options = EMPTY_HASH, &block)
      options = DEFAULTS.merge(options)
      usage_columns = DEFAULT_USAGE_COLUMNS.merge(options[:usage_columns] || EMPTY_HASH)
      model.instance_variable_set(
        :@llm_agent_options,
        options.merge(usage_columns: usage_columns.freeze).freeze
      )
      model.instance_exec(&block) if block
    end

    module ClassMethods
      def llm_plugin_options
        @llm_agent_options || Agent::DEFAULTS
      end

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

    module InstanceMethods
      private

      def ctx
        @ctx ||= begin
          options = self.class.llm_plugin_options
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

      def resolve_option(option)
        case option
        when Proc then instance_exec(&option)
        when Symbol then send(option)
        when Hash then option.dup
        else option
        end
      end

      def resolve_options(option)
        case option
        when Proc, Symbol, Hash then resolve_option(option)
        else Agent::EMPTY_HASH.dup
        end
      end
    end
  end
end
