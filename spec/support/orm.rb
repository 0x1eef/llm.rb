# frozen_string_literal: true

module LLM::Test
  class Runtime
    attr_reader :messages, :usage

    def initialize
      @messages = []
      @usage = LLM::Object.from(input_tokens: 0, output_tokens: 0, total_tokens: 0)
      @talk_result = Object.new
      @respond_result = Object.new
    end

    def talk(message)
      @messages << LLM::Message.new("user", message)
      @talk_result
    end

    def respond(message)
      @messages << LLM::Message.new("user", message)
      @respond_result
    end

    def talk_result
      @talk_result
    end

    def respond_result
      @respond_result
    end
  end

  module Harness
    module_function

    def active_record_connection
      @active_record_connection ||= begin
        ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        ::ActiveRecord::Base.connection
      end
    end

    def create_active_record_table(name)
      return if active_record_connection.data_source_exists?(name)
      active_record_connection.create_table(name) do |t|
        t.string :provider, null: false
        t.string :model, null: false
        t.text :data
        t.integer :input_tokens
        t.integer :output_tokens
        t.integer :total_tokens
      end
    end

    def build_active_record_model(name, &block)
      create_active_record_table(name)
      Class.new(::ActiveRecord::Base) do
        self.table_name = name.to_s
        class_eval(&block) if block
      end
    end

    def sequel_db
      @sequel_db ||= ::Sequel.sqlite
    end

    def create_sequel_table(name)
      return if sequel_db.table_exists?(name)
      sequel_db.create_table(name) do
        primary_key :id
        String :provider, null: false
        String :model, null: false
        String :data, text: true
        Integer :input_tokens
        Integer :output_tokens
        Integer :total_tokens
      end
    end

    def build_sequel_model(name, &block)
      create_sequel_table(name)
      Class.new(::Sequel::Model(sequel_db[name])) do
        class_eval(&block) if block
      end
    end
  end
end
