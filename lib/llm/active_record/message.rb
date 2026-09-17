# frozen_string_literal: true

module LLM::ActiveRecord
  ##
  # Represents a message in an agent's memory.
  #
  # This class is virtual and never materializes
  # in the database as a real table. It provides
  # a SQL view into the messages array stored in
  # the JSONB column that carries an agent's
  # runtime state, and it returns relations, so
  # messages can be filtered and ordered in the
  # database instead of in memory.
  #
  # It expects the agent and this class to share a
  # connection, which they do when both live on the
  # same database - the default in Rails.
  #
  # @example
  #   LLM::ActiveRecord::Message.for(agent:)
  #                             .where(role: "assistant")
  #                             .count
  class Message < ActiveRecord::Base
    ##
    # The name the derived table is given. It is "created"
    # on-demand and it is here so that ActiveRecord has
    # something to select from.
    self.table_name = "llm_agent_messages"

    ##
    # The derived table does not exist, so there is no schema
    # to load. Without this, ActiveRecord asks the database
    # for the columns of a table that was never created.
    # @return [void]
    def self.load_schema!
      @columns_hash = {}.freeze
    end

    ##
    # Build a relation over one agent's messages.
    #
    # The table, the column and its type come from the
    # agent's own class, so this works for any model that
    # keeps its conversation in a column.
    #
    # The base fields the query guarantees are columns -
    # id, role, content, tools - so they are what a
    # caller's `where` and `order` are written against.
    # The whole message is carried along as `data`, for
    # fields the query does not name yet.
    #
    # The derived table is aliased as `llm_agent_messages`
    # because ActiveRecord qualifies its SELECT with the
    # class' table name.
    #
    # @param [ActiveRecord::Base] agent
    #  An instance of an ActiveRecord model.
    # @return [ActiveRecord::Relation]
    def self.for(agent:)
      klass      = agent.class
      connection = klass.connection
      table      = connection.quote_table_name(klass.table_name)
      options    = klass.llm_plugin_options
      column     = connection.quote_column_name(options.fetch(:data_column))
      from(<<~SQL).where(agent_id: agent&.id)
        (SELECT #{table}.id                AS agent_id,
                (message ->> 'id')         AS id,
                (message ->> 'role')       AS role,
                (message ->> 'content')    AS content,
                (message -> 'tools')       AS tools,
                ordinality                 AS position,
                message                    AS data
         FROM #{table},
              jsonb_array_elements(#{table}.#{column} -> 'messages')
                WITH ORDINALITY AS each(message, ordinality))
          AS llm_agent_messages
      SQL
    end

    ##
    # @return (see LLM::Message#tool_call?)
    def tool_call?
      unwrap!.tool_call?
    end

    ##
    # @return (see LLM::Message#tool_return?)
    def tool_return?
      unwrap!.tool_return?
    end

    ##
    # The message, as the runtime would hand it back.
    #
    # The whole serialized message is used, so fields the
    # query does not name: usage, reasoning content,
    # and compaction survive the round trip through the
    # database.
    #
    # @return [LLM::Message]
    def unwrap!
      @message ||= begin
        stored = data.is_a?(Hash) ? data : {}
        extra = stored.each_with_object({}) { |(key, value), acc| acc[key.to_sym] = value }
        extra[:id] = stored["id"] || id
        extra[:role] ||= role
        extra[:content] ||= content
        extra[:tool_calls] = stored["tools"] || tools
        LLM::Message.new(extra[:role], extra[:content], extra)
      end
    end
  end
end
