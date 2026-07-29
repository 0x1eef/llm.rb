
## Database
### Introduction

#### Overview

Persistence lets an agent outlive a single session. The conversation
history, model name, and compaction status are serialized as JSON
that can be stored in a file, a database column, or transmitted
over a network. Four storage options are available:

- **Automatic filesystem persistence**: set `path:` on an agent
  for transparent auto-save after every turn (recommended for
  most file-based use-cases)
- **Filesystem**: save and restore from a JSON file on disk
- **ActiveRecord**: persist state in a database column using
  [`acts_as_agent`](https://r.uby.dev/api-docs/llm.rb/LLM/ActiveRecord.html#acts_as_agent-instance_method)
- **Sequel**: persist state in a database column using `plugin :agent`

All three use the same serialization mechanism under the hood.

#### How it works

[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
implements
[`LLM::Context#to_h`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#to_h)
and
[`LLM::Context#to_json`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#to_json)
for serialization and
[`LLM::Context#restore`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#restore)
for deserialization. Save writes the current state, restore loads
it back and picks up where the conversation left off. The ORM
wrappers automate this; each
[`LLM::Agent#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#talk)
or
[`LLM::Agent#ask`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#ask)
call persists the
updated state back to the column automatically.

#### Why would I use it?

Without persistence, every agent starts with a blank conversation.
Persistence enables long-running agents that survive process
restarts, debugging sessions that resume mid-investigation, and
conversation history that can be queried alongside application
data.

#### Notes

The saved JSON can be stored in a file, a database column, or
transmitted over the network. The ORM integrations use the same
underlying serialization as filesystem persistence.

### Automatic filesystem persistence

#### Overview

The [`LLM::Agent#path`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#path)
attribute provides transparent auto-persistence. Set a file path once
and the agent restores conversation history from that file on startup
and saves it back after every
[`LLM::Agent#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#talk)
or
[`LLM::Agent#ask`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#ask)
turn. No manual
[`LLM::Agent#save`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#save)/
[`LLM::Agent#restore`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#restore)
calls needed.

The feature is available on subclasses via the class DSL and on
direct instances via the `path:` keyword argument.

#### How it works

When a `path` is set, the agent loads existing state from the file
during initialization. After each turn
([`LLM::Agent#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#talk)
or
[`LLM::Agent#ask`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#ask)),
the updated
state is written back automatically. If the file does not exist yet,
the agent starts with a blank conversation and creates the file on
the first save.

The path can be set using any of these approaches:

##### Class DSL

```ruby
class PersistentAgent < LLM::Agent
  set model: "deepseek-v4-pro",
      path: "session.json"
end

llm = LLM.deepseek(key: ENV["KEY"])
agent = PersistentAgent.new(llm)
agent.talk "remember my name is robert"
# state saved automatically to session.json

agent2 = PersistentAgent.new(llm)
agent2.talk "what's my name?"
# restored from session.json; prints "robert"
```

##### Keyword argument

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, path: "session.json", stream: $stdout)
agent.talk "remember my name is robert"
# state saved automatically
```

##### Lazy resolution

```ruby
class DynamicAgent < LLM::Agent
  set path: -> { "sessions/#{name}.json" }
end
```

#### Why would I use it?

Auto-persistence eliminates boilerplate. You set the path once and
forget about serialization entirely. The agent picks up where it
left off across process restarts, REPL sessions, or debugging runs
without a single
[`LLM::Agent#save`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#save)
or
[`LLM::Agent#restore`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#restore)
call in your code.

#### Notes

The auto-path feature is a strict superset of manual filesystem
persistence. If you need fine-grained control over when state is
saved (e.g. batch several turns before persisting), use the manual
[`LLM::Agent#save`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#save)
and
[`LLM::Agent#restore`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#restore)
methods described in the Filesystem section below. The `path`
attribute delegates to the same underlying serialization.

### Filesystem

#### Overview

A conversation that ends when the process exits is not very useful.
Serialization saves the context (message history, model name,
compaction status) as JSON that can be stored in a string, a
file, or a database column. Restore it later, in a different
process or on a different machine, and pick up where you left off.

#### How it works

[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
implements
[`LLM::Context#to_h`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#to_h)
and
[`LLM::Context#to_json`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#to_json)
for serialization
and
[`LLM::Context#restore`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#restore)
for deserialization. The serialized state includes
the message history, model name, and compaction status. Save and
restore work with file paths or in-memory strings. You can also
serialize to a JSON string for database storage or network
transmission:

##### Save to a file

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm)
agent.talk "remember my name is robert"
agent.save(path: "agent.json")
```

##### Restore from a file

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, stream: $stdout)
agent.restore(path: "agent.json")
agent.talk "what's my name?"
```

##### Serialize to a JSON string

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm)
agent.talk "remember my name is robert"
json = agent.save
agent2 = LLM::Agent.new(llm)
agent2.restore(string: json)
```

#### Why would I use it?

Filesystem persistence is the foundation for long-running agents
that outlive a single session. Save a debugging session
mid-investigation and resume it tomorrow. Store a completed
conversation as evidence or training data. Pass context between
processes, between machines, or through a job queue.

#### Notes

[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
delegates serialization to its internal context. The
saved JSON can be stored in a file, a database column, or
transmitted over the network.

### ActiveRecord

#### Overview

ActiveRecord models use
[`LLM::ActiveRecord#acts_as_agent`](https://r.uby.dev/api-docs/llm.rb/LLM/ActiveRecord.html#acts_as_agent-instance_method)
to install the agent wrapper. The method accepts a block for
configuring agent defaults
and an options hash for storage format. Most defaults such as
`model`, `tools`, `instructions`, `schema`, and `concurrency` can
be set through the block. Tracer and stream can also be set here
rather than through legacy convention methods.

#### How it works

When you want to add agent persistence to an ActiveRecord model,
call
[`LLM::ActiveRecord#acts_as_agent`](https://r.uby.dev/api-docs/llm.rb/LLM/ActiveRecord.html#acts_as_agent-instance_method)
in the model class. The `data` column stores
the full agent state (conversation history, model name, compaction
status) as JSON. On first call, a fresh agent is created and the
conversation starts from scratch.

On subsequent calls, the stored state is restored and the
conversation continues. Every
[`LLM::Agent#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#talk)
or
[`LLM::Agent#ask`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#ask)
call persists the
updated state back to the column automatically.

The `data_column:` option lets you use a different column name.
The `format:` option controls the storage type. Use `:string` for
a text column (any database) or `:jsonb` for a native PostgreSQL
JSONB column (recommended for PostgreSQL). For `:jsonb`,
ActiveRecord handles JSON typecasting automatically.

The block yields an
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
instance. Set agent defaults in the block using the
[`LLM::Agent.set`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#set-class_method)
method or individual accessors. Anything you can set on an agent
can be
configured here -- model, tools, instructions, schema, concurrency,
tracer, stream, and confirm:

Note that `tracer` and `stream` are set directly in the block
rather than through legacy `set_tracer` / `set_context` convention
methods. The block style is the recommended approach for all agent
configuration. Only `set_provider` is required as a private method.

##### Migration with TEXT column

```ruby
class CreateAgents < ActiveRecord::Migration[7.1]
  def change
    create_table :agents do |t|
      t.string :name
      t.text :data   # stores the serialized agent state
      t.timestamps
    end
  end
end
```

##### Migration with JSONB column

```ruby
class CreateAgents < ActiveRecord::Migration[7.1]
  def change
    create_table :agents do |t|
      t.string :name
      t.jsonb :data  # native JSON storage, supports indexing
      t.timestamps
    end
  end
end
```

##### Model setup

```ruby
require "active_record"
require "llm"
require "llm/active_record"

class Agent < ApplicationRecord
  acts_as_agent(format: :jsonb) do |agent|
    agent.model "deepseek-v4-pro"
    agent.instructions "solve the user's query"
    agent.tools [Research, FinalizeResearch, ActOnResearch]
    agent.tracer LLM::Tracer::Logger.new(llm, io: $stdout)
  end

  private

  def set_provider
    LLM.deepseek(key: ENV["KEY"])
  end
end

agent = Agent.create!(name: "researcher")
agent.talk "perform research"
# state is saved to the data column automatically
```

#### Why would I use it?

The ActiveRecord wrapper integrates with your existing models.
Agent state is automatically persisted after each conversation turn
using the same `create!`, `save!`, and query methods you already
use.

#### Notes

The `format` option defaults to `:string`. Use `:json` or `:jsonb`
for PostgreSQL. JSONB is recommended; it supports indexing and
is more efficient for querying. The `data_column` option defaults
to `:data` -- create a migration to add a `TEXT` or `JSONB` column
to your table.

The model requires a `set_provider` private method that returns an
[`LLM::Provider`](https://r.uby.dev/api-docs/llm.rb/LLM/Provider.html)
instance. Legacy `set_context` and `set_tracer` convention methods
also work for backwards compatibility, but the block style
(`agent.tracer ...`, `agent.stream ...`) is preferred for all
agent-level configuration.

### Sequel

#### Overview

Sequel models use `plugin :agent` to install the agent wrapper.
The plugin accepts the same options as `acts_as_agent` and follows
the same conventions for provider resolution and state persistence.
On first call, a fresh agent is created and the conversation starts
from scratch. On subsequent calls, the stored state is restored and
the conversation continues automatically.

#### How it works

When you want to add agent persistence to a Sequel model, register
the plugin in the model class. The `data` column stores
the full agent state as JSON, same structure as ActiveRecord.
On first call, a fresh agent is created. On subsequent calls,
the stored state is restored and the conversation continues.
Every
[`LLM::Agent#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#talk)
or
[`LLM::Agent#ask`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#ask)
call persists the updated state.

The `data_column:` and `format:` options work identically to
ActiveRecord. For `:jsonb`, Sequel loads the `pg_json` extension
automatically and handles JSON typecasting. The block yields an
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
instance. Configure agent defaults in the block -- model, tools,
instructions, tracer, stream, and confirm all go here:

As with ActiveRecord, `tracer` and `stream` are configured in the
block rather than through legacy convention methods. The block
style is the recommended approach.

##### Migration with TEXT column

```ruby
DB.create_table :agents do
  primary_key :id
  String :name
  String :data       # stores the serialized agent state
  DateTime :created_at
  DateTime :updated_at
end
```

##### Migration with JSONB column

```ruby
DB.create_table :agents do
  primary_key :id
  String :name
  column :data, :jsonb  # native JSON storage
  DateTime :created_at
  DateTime :updated_at
end
```

##### Model setup

```ruby
require "sequel"
require "llm"
require "llm/sequel/plugin"

class Agent < Sequel::Model
  plugin(:agent, format: :jsonb) do |agent|
    agent.model "deepseek-v4-pro"
    agent.instructions "solve the user's query"
    agent.tools [Research, FinalizeResearch, ActOnResearch]
    agent.tracer LLM::Tracer::Logger.new(llm, io: $stdout)
  end

  private

  def set_provider
    LLM.deepseek(key: ENV["KEY"])
  end
end

agent = Agent.create(name: "researcher")
agent.talk "perform research"
# state is saved to the data column automatically
```

#### Why would I use it?

The Sequel plugin integrates with your existing models.
It follows the same conventions as ActiveRecord, so
switching between the two requires minimal code changes.

#### Notes

The `format` option defaults to `:string`. Use `:json` or `:jsonb`
for PostgreSQL. Sequel loads the `pg_json` extension automatically
and wraps JSON values for native storage. JSONB is recommended.
The `data_column` option defaults to `:data`.

The model requires a `set_provider` private method that returns an
[`LLM::Provider`](https://r.uby.dev/api-docs/llm.rb/LLM/Provider.html)
instance. Legacy `set_context` and `set_tracer` convention methods
also work for backwards compatibility, but configuring tracer,
stream, and other agent options in the block is the preferred
approach.

