<p align="center">
  <a href="https://r.uby.dev">
    <img
      src="https://github.com/r-uby-dev/llm.rb/raw/main/rubydev.svg"
      width="400"
      height="200"
      border="0"
      alt="a r.uby.dev project"
     >
  </a>
</p>

> A [r.uby.dev](https://r.uby.dev/llm) project.

Welcome to the canonical llm.rb repository.

llm.rb is an advanced runtime for building capable AI applications
on CRuby. It has zero runtime dependencies by default, and a single
coherent API that spans 13+ providers. Streaming, tools, guards,
compaction, the REPL, builtin MCP/A2A support and the database
integrations all build on the same three concepts: providers,
contexts, and agents.

Once you learn the fundamentals, everything else falls into place
naturally. Some features, such as ActiveRecord support, require
optional dependencies that are opt-in.

It is recommended to read the [deepdive.md](https://r.uby.dev/llm/deepdive)
guides if you want to learn more about llm.rb. I read them from time to time
and put a lot of effort into maintaining the deepdive and associated
documentation. The deepdive covers all llm.rb features.

## Install

```bash
gem install llm.rb
```

## Quick start

#### Providers

Each provider is constructed with a class-level factory method on
`LLM`, and the resulting instance is passed to
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
or
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html). The
same API also drives Google Gemini, DeepInfra, xAI, Z.ai, AWS
Bedrock, Ollama, and llama.cpp. See the [deepdive](https://r.uby.dev/llm/deepdive/fundamentals/providers)
for a full provider reference.

##### Implicit

Cloud providers can infer their API key automatically
from a set of common defaults that are defined by
the [models.dev](https://models.dev) registry that
is also distributed with llm.rb.

```ruby
llm = LLM.openai
llm = LLM.anthropic
llm = LLM.deepseek
llm = LLM.alibaba  # also: LLM.aliyun
llm = LLM.moonshot
llm = LLM.mistral
```

##### Explicit

The `key` option can also be providied explicitly, and certain
providers (eg ollama, llamacpp) usually do not require an API
key at all.

```ruby
llm = LLM.openai(key: ENV["OPENAI_API_KEY"])
llm = LLM.anthropic(key: ENV["ANTHROPIC_API_KEY"])
llm = LLM.deepseek(key: ENV["DEEPSEEK_API_KEY"])
llm = LLM.alibaba(key: ENV["DASHSCOPE_API_KEY"]) # also: LLM.aliyun
llm = LLM.moonshot(key: ENV["MOONSHOT_API_KEY"])
llm = LLM.mistral(key: ENV["MISTRAL_API_KEY"])
```

#### LLM::Agent

The
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
class is the default high-level interface,
and it is recommended for most use-cases. It manages tool execution
automatically and
[guards against infinite loops](https://r.uby.dev/llm/deepdive/advanced/guard),
manages conversation state, and much more.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, stream: $stdout)
agent.talk "Hello world"
```

##### set

[`LLM::Agent.set`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#set-class_method)
is a class-level DSL that accepts a Hash of properties. Each key resolves to a
corresponding class accessor: `name`, `description`, `model`, `tools`,
`instructions`, `schema`, `stream`, `tracer`, `concurrency`, `confirm`,
`path`, `skills`, `tool_budget`, and `retry_budget`. All options are
optional; zero or more can be set.
An error is raised for unknown keys so that typos are caught early.

```ruby
class Agent < LLM::Agent
  set name: "sysadmin",
      description: "system administration agent",
      model: "deepseek-v4-pro",
      tools: [Shell]
end

llm = LLM.deepseek(key: ENV["KEY"])
agent = Agent.new(llm)
agent.talk "Run 'date'"
```

##### Persistence

Set `path:` on an agent for automatic filesystem persistence;
the agent restores conversation history from the file on startup
and saves it back after every turn, with no manual serialization
code. For database-backed persistence, ActiveRecord and Sequel
integrations are also available (see the
[database deepdive](https://r.uby.dev/llm/deepdive/fundamentals/database)
for details). All persistence options use the same underlying
serialization.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, path: "session.json")
agent.talk "remember my name is robert"

# Next time, the conversation is restored automatically:
agent = LLM::Agent.new(llm, path: "session.json")
agent.talk "what's my name?"
```

##### Automatic retries

Rate-limited requests are retried automatically by default. Agents
retry a 429 up to three times with a growing backoff before giving
up, so most request failures resolve on their own. Set `retry_budget`
to change the number of retries, or `retry_budget: 0` to disable
them.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, retry_budget: 0)
```

#### LLM::Context

The
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
class is at the heart of the runtime
and it is what
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
uses under the hood.
It requires that the tool call loop be managed manually -
sometimes that can be useful, but usually for advanced use-cases.
If you're new to llm.rb, try
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html) first.

Every context tracks its own token usage and estimated cost. After any
turn, you can read the cost breakdown through
[`LLM::Context#cost`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#cost-instance_method),
and the REPL shows the running total in the status line.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: $stdout)
ctx.talk "Hello world"
```

#### LLM::Tool

Subclasses of
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html)
are plain Ruby classes with
an optional set of typed parameters. <br> The model can choose to
call them on your behalf, and they're one of the most powerful features
for extending the feature set or abilities of a model.

The runtime also ships with a catalog of built-in tools for
filesystem, search, and shell operations. See the
[deepdive.md](https://r.uby.dev/llm/deepdive/fundamentals/builtin_tools)
for details.

```ruby
class ReadFile < LLM::Tool
  name "read-file"
  description "Read a file"
  parameter :path, String, "The filename or path"
  required %i[path]

  def call(path:)
    {contents: File.read(path)}
  end
end
```

##### set

[`LLM::Tool.set`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#set-class_method)
is an alternative way to define tool properties using a Hash. It works
the same way as
[`LLM::Agent.set`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#set-class_method)
and accepts the same keys that the individual methods do: `name`,
`description`, `parameters`, `required`, and `defaults`:

```ruby
class MathTool < LLM::Tool
  set name: "math",
      description: "Performs arithmetic",
      parameters: [
        [:x, Integer, "first number" , {required: true}],
        [:y, Integer, "second number", {default: 0}]
      ]

  def call(x:, y: 0)
    {result: x + y}
  end
end
```

#### LLM::Stream

Streams can be simple IO objects or subclasses of
[`LLM::Stream`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html)
with structured callbacks for content,
reasoning, tool calls, tool returns, and compaction.
Streams can also observe message transformers, which rewrite
outgoing messages before they reach the provider (see the
[deepdive.md](https://r.uby.dev/llm/deepdive/advanced/transformer)).

```ruby
class MyStream < LLM::Stream
  def on_content(content)
    print content
  end

  def on_reasoning_content(content)
    warn content
  end
end

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, stream: MyStream.new)
agent.talk "Explain Ruby fibers."
```

#### LLM::Schema

[`LLM::Schema`](https://r.uby.dev/api-docs/llm.rb/LLM/Schema.html)
subclasses produce typed, structured
output from any model call. Pass a schema to
[`LLM::Context#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#talk-instance_method),
[`LLM::Agent#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#talk-instance_method),
or
[`LLM::Provider#complete`](https://r.uby.dev/api-docs/llm.rb/LLM/Provider.html#complete-instance_method)
to receive validated JSON instead of free text. Schemas work alongside tools and streams.

[`LLM::Schema`](https://r.uby.dev/api-docs/llm.rb/LLM/Schema.html)
can define objects, arrays, enums, nested schemas,
and more. It is also used internally by
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html) for parameter
definitions, so you already benefit from it when you declare tool
parameters.

The
[`LLM::DeepSeek`](https://r.uby.dev/api-docs/llm.rb/LLM/DeepSeek.html)
provider includes runtime-level optimisations such as structured
output support (despite no official structured outputs API) and
SVG image generation. This example uses
[`LLM::Schema`](https://r.uby.dev/api-docs/llm.rb/LLM/Schema.html) with
DeepSeek:

```ruby
class Weather < LLM::Schema
  property :city, String, "The city name"
  property :temperature, Number, "Current temperature"
  property :conditions, String, "Weather conditions"
  required %i[city temperature conditions]
end

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, schema: Weather)
res = agent.talk "Weather in Paris?"
res.content!  # => {city: "Paris", temperature: 15.0, conditions: "Cloudy"}
```

#### LLM::REPL

The [LLM::Agent#repl](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#repl-instance_method)
method drops you into a highly capable read-eval-print loop (REPL)
that is built on top of curses. It can help you debug agents,
test your tools, connect to MCP servers, and even A2A agents.
The REPL stands out because it connects to the surrounding
runtime and it can be extended by your code. Think of it as
`binding.pry` but for agents.

##### Installation

The REPL is distributed with llm.rb so you don't have to install
a separate gem but it requires a number of optional dependencies
to be installed separately. The following gems provide the full
experience:

    gem install curses kramdown xchan.rb test-cmd.rb

##### Persistence

The `path:` option can be set on an agent for automatic persistence
across REPL sessions. The `tools:` option attaches extra tools
for the duration of the session. Recall previous turns with Ctrl+P and
Ctrl+N. For the full reference, see the REPL section in the
[deepdive.md](https://r.uby.dev/llm/deepdive/fundamentals/repl)
document.

```ruby
require "llm"
require "llm/tools"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, name: "my-agent", path: "agent.json")
agent.repl(tools: LLM::Tool.subclasses)
```

##### CLI

The `llm.rb` executable is available on your PATH after installation.
It starts a REPL session from any directory.The CLI auto-detects your
provider from standard environment variables (`DEEPSEEK_API_KEY`,
`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc.). Persistent sessions are
stored under `~/.llm.rb/` and restored automatically on your next visit.

```bash
llm.rb                     # auto-detect from $DEEPSEEK_API_KEY
llm.rb -p openai           # use OpenAI explicitly
llm.rb -t                  # temporary session, no persistence
```

#### LLM::MCP

The Model Context Protocol (MCP) has first-class support
in llm.rb. The stdio and http transports work out of the
box. MCP tools are translated into subclasses of
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html) that can be
used with
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html) or
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html).

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
mcp   = LLM::MCP.stdio(argv: ["ruby", "server.rb"])
agent = LLM::Agent.new(llm, stream: $stdout, tools: mcp.tools)
agent.talk "Run the tool"
```

##### Persistent connections

Set `persistent: true` on HTTP transports to reuse connections
across requests. This uses
[`Net::HTTP::Persistent`](https://github.com/drbrain/net-http-persistent)
under the hood and avoids opening a new TCP connection for every
request:

```ruby
mcp = LLM::MCP.http(
  url: "https://api.githubcopilot.com/mcp/",
  headers: {"Authorization" => "Bearer #{ENV.fetch('GITHUB_PAT')}"},
  persistent: true
)
```

#### LLM::A2A

The Agent 2 Agent (A2A) protocol has first-class support
in llm.rb. The http and jsonrpc transports work out of the
box. A2A skills are translated into subclasses of
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html) that can be
used with
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html) or
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html).

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
a2a   = LLM::A2A.rest(url: "https://remote-agent.example.com")
agent = LLM::Agent.new(llm, stream: $stdout, tools: a2a.skills)
agent.talk "Run the skill"
```

##### Persistent connections

Set `persistent: true` on HTTP transports to reuse connections
across requests. This uses
[`Net::HTTP::Persistent`](https://github.com/drbrain/net-http-persistent)
under the hood and avoids opening a new TCP connection for every
request:

```ruby
a2a = LLM::A2A.rest(url: "https://agent.example.com", persistent: true)
a2a = LLM::A2A.jsonrpc(url: "https://agent.example.com", persistent: true)
```

#### LLM::Guard

[`LLM::Guard`](https://r.uby.dev/api-docs/llm.rb/LLM/Guard.html)
is the hook that sees every tool call before it runs. A guard
can let a call through, cancel it, block it with an error, or
even answer for it. Because it runs before the tool, anything
it intercepts never executes. Policy, validation, quotas, and
cost ceilings all live here.

[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
enables
[`LLM::Guard::Loop`](https://r.uby.dev/api-docs/llm.rb/LLM/Guard/Loop.html)
by default, so agents get loop protection out of the box. To
write your own guard, subclass
[`LLM::Guard`](https://r.uby.dev/api-docs/llm.rb/LLM/Guard.html)
and implement
[`LLM::Guard#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Guard.html#call-instance_method).
The pending call arrives as `function:`. Return a value to close
the call, or `nil` to let it run:

```ruby
class PolicyGuard < LLM::Guard
  def call(function:)
    if function.name == "shell"
      function.return(error: true, type: "policy_error",
                      message: "shell is disabled")
    end
  end
end

agent = LLM::Agent.new(llm, guard: PolicyGuard)
```

#### LLM::Skill

A skill turns a markdown file into a callable tool. When the model
calls it, the runtime spawns a subagent with the skill's instructions
as its system prompt and the skill's own tool set. The subagent runs
one turn and returns the result, then is discarded. Each call
is fresh and stateless. For a deeper explanation see the
[deepdive.md](https://r.uby.dev/llm/deepdive/fundamentals/skills).

##### SKILL.md

```markdown
---
name: summary
description: Reads recent git history and writes a summary
tools: all
---

Collect the recent git log, analyze each commit,
and write a summary to summary.txt.
```

##### agent.rb

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, skills: ["./skills/summary"])
agent.talk "Summarize the last week of work"
```

#### RAG

Most providers offer an embedding model that can be
used for semantic search, or similarity search. An
embedding model can generate embeddings that can then
be stored in a database that is optimized for storing
and querying vectors, such as SQLite's [sqlite-vec](https://github.com/asg017/sqlite-vec)
or PostgreSQL's [pg-vector](https://github.com/pgvector/pgvector).

llm.rb also includes support for OpenAI's vector store API. It
provides a vector database as a HTTP service but we won't cover
that here. For a deeper explanation see the
[deepdive.md](https://r.uby.dev/llm/deepdive/fundamentals/embeddings).

```ruby
require "llm"

llm  = LLM.openai(key: ENV["KEY"])
body = "llm.rb is Ruby's capable AI runtime."
embedding = llm.embed([body]).embeddings.first

# Document is your ActiveRecord or Sequel model
# with a vector column (e.g. sqlite-vec or pgvector)
Document.create!(
  title: "llm.rb",
  body:,
  embedding:,
)
```

#### Concurrency

The runtime supports six different concurrency strategies that have
different attributes. The choice between all of them often depends
on the requirements of your application.

IO-bound tools are a good fit for the `:async`, `:thread`,
and `:fiber` strategies while true parallelism can be achieved
with the `:fork` and `:ractor` strategies. The
`:sequential` strategy runs tools one at a time and is the default.
The `:fork` strategy also provides a separate process that offers
isolation from its parent.

You can learn more about the llm.rb concurrency model in the
[deepdive.md](https://r.uby.dev/llm/deepdive/fundamentals/concurrency).

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
tools = [FetchNews, FetchStocks, FetchFeeds]
agent = LLM::Agent.new(llm, tools:, concurrency: :fork)
agent.talk "Run the tools in parallel"
```

#### ORM

Because both
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html) and
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
can be serialized to JSON and stored in a simple string, both ActiveRecord
and Sequel support can be implemented within a single column on a single row.

The runtime includes first-class support for both ActiveRecord *and* Sequel, and
for both Rack-based applications *and* Rails-based applications. On databases
where it is supported, such as PostgreSQL, the column can be optimized by using
the `jsonb` type.

```ruby
require "active_record"
require "llm"
require "llm/active_record"

class Agent < ApplicationRecord
  acts_as_agent do |agent|
    agent.set name: "my-agent",
              instructions: "solve the user's query",
              model: "deepseek-v4-pro",
              tools: [Research, ActOnResearch],
              concurrency: :async
  end

  def research
    talk("start the research")
  end

  def act_on_research!
    talk("act on the research")
  end

  private

  ##
  # By convention, this method defines the provider for a model.
  # If necessary, it can be renamed with: provider: :your_method.
  def set_provider
    LLM.deepseek(key: ENV["KEY"])
  end

  ##
  # By convention, this method returns the context options given
  # to LLM::Context or LLM::Agent. This method can be left undefined.
  def set_context
    {}
  end
end

agent = Agent.create!
agent.research
agent.act_on_research!
```

#### Images

A handful of providers can generate images from a text prompt.
OpenAI, Google, xAI, and DeepInfra all support it. The API is
the same across providers:

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.images.create(prompt: "a dog on a rocket to the moon")
IO.copy_stream res.images[0], "rocket.png"
```

##### DeepSeek

DeepSeek does not have a dedicated image model, but the runtime
generates SVG vector graphics through its text model. Each
generation produces a valid SVG document that can be converted
to PNG with tools like `rsvg-convert`. Pass an existing agent
to maintain a session across generations:

```ruby
require "llm"
llm = LLM.deepseek(key: ENV["KEY"])

##
# First generation
res = llm.images.create(prompt: "a rocket on the moon")
IO.copy_stream res.images[0], "rocket.svg"

##
# Refine with follow-up prompts (shares context)
res = llm.images.create(prompt: "add a dog next to the rocket",
                        agent: res.agent)
IO.copy_stream res.images[0], "rocket-with-dog.svg"
```

## Features

One runtime, 13+ providers. The same API drives OpenAI, Anthropic,
Google Gemini, Moonshot (kimi), Alibaba (Qwen3), Mistral, DeepSeek,
DeepInfra, xAI, Z.ai, AWS Bedrock, Ollama, and llama.cpp, so switching
models or providers can be done with minimal code change.

<details>
<summary><b>Agents</b></summary>

* **First-class support** <br>
  llm.rb is designed to build agents. They can be attached to a
  terminal-based read-eval-print loop (repl), persisted to disk
  or a database column, run tools concurrently and be safely
  interrupted.

* **Builtin REPL** <br>
  A curses-based TUI for talking to an agent interactively. It
  renders markdown, shows a live status line with context usage
  and running cost, and recalls previous turns, so a
  conversation survives a restart.

* **Persistence** <br>
  Set `path:` and the agent saves its conversation to disk
  automatically. ActiveRecord and Sequel support keep the same
  state in a single database column, so you pick the storage
  and the API stays identical.

</details>

<details>
<summary><b>MCP &amp; A2A</b></summary>

* **MCP** <br>
  The Model Context Protocol is first-class. Point an MCP client
  at any tool server over stdio or HTTP, and its tools translate
  into local `LLM::Tool` subclasses, with the same tracing and
  error handling.

* **A2A** <br>
  The Agent 2 Agent protocol is first-class. Point an A2A client
  at another agent over HTTP or JSON-RPC, and call its skills
  exactly like local tools.

</details>

<details>
<summary><b>ORM</b></summary>

* **ActiveRecord** <br>
  Add `acts_as_agent` to a model and the agent state lives in a
  single database column, saved after every turn and restored
  on load. Works in Rack and Rails apps, with `jsonb` on
  PostgreSQL.

* **Sequel** <br>
  Add `plugin :agent` to a Sequel model for the same single-
  column persistence, with the `pg_json` extension loaded
  automatically on PostgreSQL.

</details>

<details>
<summary><b>RAG</b></summary>

* **RAG, out of the box** <br>
  Embeddings, OCR, and OpenAI's vector stores API come first-
  class. Ground answers in your own documents, with vectors in
  a managed store or in your own database such as sqlite-vec
  or pgvector.

</details>

<details>
<summary><b>Runtime</b></summary>

* **Streaming** <br>
  Streaming is first-class, with structured callbacks for
  content, reasoning, and tool calls. Tools can start while
  the model is still talking, so the first result lands
  before the response finishes.

* **Concurrency** <br>
  Six ways to run tools: sequential, threads, async, fibers,
  forks, and ractors. Plus three HTTP backends, so you pick
  the concurrency model that fits the workload, not the other
  way around.

* **Interruption** <br>
  Cancel an in-flight request or a running tool at any moment,
  on any transport or concurrency strategy. A stuck call never
  leaves a thread running that you can't stop.

* **Rate-limit retries** <br>
  Rate-limited requests are retried automatically. Agents retry
  up to three times with a growing backoff, and notify your
  stream through `on_rate_limit` before each retry.

</details>

<details>
<summary><b>Provider extras</b></summary>

* **DeepSeek-optimized** <br>
  DeepSeek is the most cost-effective option for API users, and the
  runtime closes its gaps: [`LLM::Schema`](https://r.uby.dev/api-docs/llm.rb/LLM/Schema.html)
  makes structured outputs work despite no official API, and
  `images.create`/`edit` produce SVG vector graphics.
</details>

<details>
<summary><b>Portable</b></summary>

* **mruby-llm** <br>
  The same runtime runs on mruby as
  [mruby-llm](https://github.com/r-uby-dev/mruby-llm), with an
  almost identical interface and the same set of capabilities.

</details>

<details>
<summary><b>Everything else</b></summary>

* **Skills** <br>
  Write a SKILL.md, get a tool. The runtime spawns a
  disposable subagent with the skill's instructions and tool
  set for one turn, then discards it. Fresh and stateless
  every call.

* **A unified plugin family** <br>
  Compactors, transformers, and guards all share one
  interface. Context management, message rewriting, and tool
  supervision (policy, quotas, loop detection) plug in the
  same way and compose freely.

* **Cost and usage tracking** <br>
  Every context tracks its own cost and token usage, per turn.
  Break the spend down by input, output, cache, and reasoning,
  so the exact cost of any conversation is visible at a
  glance.

</details>

## FAQ

<details>
<summary>What providers does llm.rb support?</summary>
<br>
<p>

**Cloud**

The following cloud-based providers are available to choose from. <br>
In no particular order:

🇺🇸 OpenAI <br>
🇺🇸 DeepInfra <br>
🇺🇸 xAI <br>
🇺🇸 Google (Gemini) <br>
🇺🇸 AWS bedrock <br>
🇺🇸 Anthropic <br>
🇨🇳 DeepSeek <br>
🇨🇳 zAI <br>
🇨🇳 Moonshot AI (Kimi) <br>
🇨🇳 Alibaba (Qwen3) <br>
🇪🇺 Mistral <br>

**Weights**

The following providers provide access to open-weight models. <br>
In no particular order:

🇺🇸 DeepInfra <br>
🇺🇸 AWS bedrock <br>
🇨🇳 DeepSeek <br>
🇨🇳 zAI <br>
🇨🇳 Moonshot AI (Kimi) <br>
🇨🇳 Alibaba (Qwen3) <br>
🇪🇺 Mistral <br>

**Local**

The following providers can be run locally on your own hardware. <br>
In no particular order:

* Ollama
* Llamacpp
</p>
</details>

<details>
<summary>I have a limited budget. What should I do?</summary>
<br>
<p>
There are a few options. The first option is to host
your own model, and use the ollama or llamacpp
providers. This can be difficult though because
a capable model requires hardware that can
match it. If you have the ability to self-host,
this would be my first option.
</p>
<p>
The second option is DeepSeek. <br>
The deepseek-v4-flash model costs pennies to use. <br>
And llm.rb has been optimized for deepseek. For example,
DeepSeek does not have image generation capabilities
but on the llm.rb runtime it does (vector graphics only,
though).
</p>
<p>
The same is true for structured outputs. DeepSeek does
not support structured outputs in the same way as OpenAI or
Google, but the llm.rb runtime makes it appear as
though it does, through the `json_object` response
type.
</p>
If you're on a budget, DeepSeek is hard to beat.
</details>
<details>
<summary>Can I download llm.rb via a decentralized network?</summary>
<br>
Yes.
<br>
We are on the <a href="https://radicle.network">radicle.network</a>
<br>
Every commit that lands on GitHub also lands on Radicle.
<br>
Our repository ID is z2PtfQ6dYwyYaW2aGrztG1sMyDmCE.
<br>
Browse on <a
href="https://radicle.network/nodes/iris.radicle.network/z2PtfQ6dYwyYaW2aGrztG1sMyDmCE">the
web</a>.
</details>

## Resources

If you like what you read so far, check out the [deepdive.md](https://r.uby.dev/llm/deepdive/)
to learn more. Unfortunately it
wasn't possible to cover every feature without the README becoming a small book.
The [r.uby.dev](https://r.uby.dev) homepage also includes more learning material
and resources.

## Developers

The llm.rb project is quite large and maintained primarily by one
person. It would be near impossible for me to maintain both the codebase
and its documentation, especially the [deepdive.md](https://r.uby.dev/llm/deepdive/)
so I have written agents that maintain the documentation assets and that
allows me to put more focus on the code.

The following agents are available for those tasks, and all of them
use the most cost effective option: DeepSeek. Feel free to use them
in your own fork.

```sh
##
# Maintains the deepdive and API docs
rake agents:scribe:yardoc
rake agents:scribe:coverage
rake agents:scribe:regressions
rake agents:scribe:style
rake agents:scribe:changelog
rake agents:scribe:repl

##
# Maintains the release
rake agents:rel:release
rake agents:rel:repl

##
# Maintains mruby-llm backports
rake agents:mruby:research
rake agents:mruby:code
rake agents:mruby:repl

##
# Refresh the data/ registry
rake models.dev:download
```

## License

This software is released under the terms of the MIT license. <br>
See [LICENSE](./LICENSE) for details.
