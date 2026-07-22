<p align="center">
  <a href="https://r.uby.dev/llm/">
    <img
      src="https://github.com/r-uby-dev/llm.rb/raw/main/rubydev.svg"
      width="400"
      height="200"
      border="0"
      alt="a r.uby.dev project"
    >
  </a>
</p>

> A [r.uby.dev](https://r.uby.dev) project.

## Welcome

Welcome to the llm.rb deepdive. You are reading this document
in the markdown format. An optimized version exists
at [https://r.uby.dev/llm/deepdive](https://r.uby.dev/llm/deepdive)
and it is both easier to read and navigate.

This document is a continuation of the [homepage documentation](https://r.uby.dev/llm).
It assumes you are familiar with the basics already, and focuses on
features that didn't make it into the homepage documentation.

## Table of contents

**Overview**

- [Welcome](#welcome)

**Core**

<details>
<summary>Agents</summary>

- [As a subclass](#as-a-subclass)
- [As an object](#as-an-object)
</details>

<details>
<summary>Tools</summary>

- [LLM::Tool](#llmtool)
- [Errors](#errors)
- [Confirmation](#confirmation)
- [Manual tool loop](#manual-tool-loop)
  - [Executing](#executing)
  - [Per-tool confirmation](#per-tool-confirmation)
  - [Full loop](#full-loop)
  - [Trade-offs](#trade-offs)
</details>

<details>
<summary>Skills</summary>

- [Overview](#overview-1)
- [How it works](#how-it-works)
- [Why this matters](#why-this-matters)
- [Frontmatter](#frontmatter)
</details>

<details>
<summary>Schema</summary>

- [Estimation](#estimation)
</details>

**Runtime**

<details>
<summary>Stream</summary>

- [IO-like object](#io-like-object)
- [LLM::Stream](#llmstream)
</details>

<details>
<summary>Concurrency</summary>

- [Overview](#overview)
- [sequential](#sequential)
- [thread](#thread)
- [fiber](#fiber)
- [async](#async)
- [fork](#fork)
- [ractor](#ractor)
- [Quick reference](#quick-reference)
</details>

<details>
<summary>Context Compaction</summary>

- [Configuration](#configuration)
- [Standalone usage](#standalone-usage)
- [Strategies](#strategies)
- [Manual compaction](#manual-compaction)
- [Lifecycle callbacks](#lifecycle-callbacks)
</details>

<details>
<summary>Cancellation</summary>

- [Cancel a request](#cancel-a-request)
- [Tool interrupts](#tool-interrupts)
</details>

<details>
<summary>Transports</summary>

- [net/http](#nethttp)
- [net/http/persistent](#nethttppersistent)
- [curb](#curb)
</details>

<details>
<summary>Tracer</summary>

- [Provider-wide tracer](#provider-wide-tracer)
- [Agent-local tracer](#agent-local-tracer)
</details>

<details>
<summary>REPL</summary>

- [LLM::Agent](#llmagent)
- [Persistence](#persistence)
- [Tools](#tools)
- [Skills](#skills-1)
- [Tracer](#tracer-1)
- [Input](#input)
- [Commands](#commands)
</details>

**Persistence**

<details>
<summary>Serialization</summary>

- [Save to disk](#save-to-disk)
</details>

<details>
<summary>ORM</summary>

- [ActiveRecord](#activerecord)
- [Sequel](#sequel)
</details>

**Media**

<details>
<summary>Images</summary>

- [Generation](#generation)
- [Edits](#edits)
- [DeepSeek](#deepseek)
</details>

<details>
<summary>Audio</summary>

- [text-to-speech](#text-to-speech)
- [speech-to-text](#speech-to-text)
- [translation](#translation)
</details>

<details>
<summary>OCR</summary>

- [Mistral](#mistral)
</details>

**Protocols**

<details>
<summary>MCP</summary>

- [stdio](#stdio)
- [http](#http)
</details>

<details>
<summary>A2A</summary>

- [rest](#rest)
- [jsonrpc](#jsonrpc)
</details>

## Agents

An agent is represented by the
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
class, and it is built on top of
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html) -
the heart of the runtime. An agent manages the tool loop automatically,
implements a tool loop guard for misbehaving models, and
it can use six different concurrency strategies to execute
tools.

An agent can be a subclass of
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html),
or a direct
instance of it. The subclass approach is useful when you
want reusable agents that can attach behavior (as methods)
to their own class.

#### As a subclass

A subclass of
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
can define its model, tools,
and other attributes at the class-level. All of these
attributes are optional, and they act as defaults that
can be overriden on the instance level.

The example uses the `:fork` concurrency model. It has
two primary benefits: tools are run in parallel, and in
a separate process with a separate memory address space.

The example purposefully demonstrates how the attributes
can be lazily defined with a block, or a Symbol that is
evaluated as an instance method on the subclass. It is
not strictly neccessary, though, and the example would
be simpler without it.

```ruby
class Agent < LLM::Agent
  set model: "deepseek-v4-pro",
      tools: [DoResearch, FinalizeResearch, ActOnResearch],
      stream: -> { $stdout },
      tracer: :set_tracer,
      concurrency: :fork

  def research!
    talk "start the research"
  end

  private

  def set_tracer
    LLM::Tracer::Logger.new(llm, io: $stderr)
  end
end
llm   = LLM.deepseek(key: ENV["KEY"])
agent = Agent.new(llm).tap(&:research!)
agent.talk "How did the research go?"
```

#### As an object

The more direct, and sometimes more convienent approach, is to
create an instance of
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
directly. The same attributes can be provided as the
second argument given to
[`LLM::Agent.new`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html),
and the same lazy evaluation rules apply. This approach can be
great for prototyping quickly, and you can always turn to a
subclass later if that makes more sense.

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, stream: $stdout)
agent.talk "Hello, fellow agent"
```

[Back to top](#table-of-contents)

## Tools

A tool extends the capabilities of a model. <br>
A tool is a subclass of
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html)
that has a name,
a description, and an optional set of typed parameters.

A tool also has a method associated with it, and when the
model calls a tool it will do so through this method,
alongside any parameters the tool might have defined.

In other words, a tool provides a way for a model to
call a method you have written, and it returns a value
to the model that is considered the tool's response.
The model then proceeds to process the tool's response,
and then might generate its own response, or perhaps call
another tool.

There is exactly one rule: a tool call must always produce
a tool response. If a tool raises an exception, the runtime
rescues it and returns a structured error to the model
instead. The conversation never enters an invalid state
because of a crashed tool. The model always has
something to work with. This is by design. Keeping the
tool loop alive is the highest priority.

#### LLM::Tool

A tool can be defined by subclassing
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html)
with
a name, description, and optional set of parameters. The
tool name, and description should be informative so the
model can understand what the tool does and how it can
serve a user's query.

```ruby
require "llm"
require "shellwords"

class Shell < LLM::Tool
  name "shell"
  description "execute a shell command"
  parameter :name, String, "the command's name"
  parameter :arguments, Array[String], "One or more arguments"
  required %i[name]
  defaults arguments: []

  def call(name:, arguments: [])
    out = `#{name.shellescape} #{arguments.map(&:shellescape).join(" ")}`
    {ok: $?.success?, out:}
  end
end

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tools: [Shell], stream: $stdout)
agent.talk "What files are in the current working directory?"
```

#### Errors

Exceptions raised by a tool are automatically rescued and
returned to the model as a structured error. The model sees
something like this:

```ruby
class Error < LLM::Tool
  name "error"
  description "demo how errors are handled"

  ##
  # Returns
  # {error: true, type: "RuntimeError", message: "boom"}
  def call
    raise "boom"
  end
end
```

The runtime wraps the exception into `{error: true, type: "RuntimeError",
message: "boom"}` and returns it to the model as the tool response. From
the model's perspective the tool completed. It just completed with
an error. The model can read the error, decide what went wrong, and try
something else. The conversation stays valid.

You can also handle errors yourself inside `call`. Rescue the exception
and return whatever shape makes sense for your tool:

```ruby
class Shell < LLM::Tool
  name "shell"
  description "execute a shell command"

  def call(name:, arguments: [])
    out = `#{name} #{arguments.join(" ")}`
    {ok: $?.success?, out:}
  rescue Errno::ENOENT
    {ok: false, error: "command not found: #{name}"}
  end
end
```

The model receives `{ok: false, error: "command not found: ls"}` and can
react accordingly. Maybe it corrects the command name and tries
again. This is often better than letting the runtime's generic error
wrapper speak for you, because you can provide domain-specific detail
that helps the model recover.

The principle is the same either way: **return something**. A tool call
must complete with a tool response. If you don't return a value, and you
don't raise, the runtime has nothing to send back and the conversation
is stuck. As long as you return a Hash (or anything the model can
interpret), the tool loop continues.

#### Confirmation

Tools that perform destructive actions can be gated behind
explicit confirmation. List their names in
[`LLM::Agent.confirm`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#confirm-class_method)
to block execution until you override `on_tool_confirmation`.

The default handler cancels the tool. Override it per-agent to
prompt the user, log the decision, or auto-approve certain tools.

```ruby
class AdminAgent < LLM::Agent
  set confirm: %w[delete destroy shutdown]

  def on_tool_confirmation(fn, strategy)
    print "Run #{fn.name} with #{fn.arguments}? [y/N] "
    $stdin.gets&.match?(/\Ay\z/i) ? fn.task(strategy).wait : fn.cancel
  end
end

llm = LLM.deepseek(key: ENV["KEY"])
agent = AdminAgent.new(llm)
```

Confirmation also accepts a Symbol for lazy resolution, which
allows the list of confirmed tools to change per-instance:

```ruby
class AdaptiveAgent < LLM::Agent
  set confirm: :tools_that_need_confirmation

  def tools_that_need_confirmation
    some_condition ? %w[delete destroy] : %w[delete]
  end
end
```

## Manual tool loop

[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html) manages
the tool loop automatically. It calls the model, checks for tool calls,
executes them, sends results back, and repeats until the model responds
with text. You can bypass this and drive the loop yourself for finer
control.

Start with a bare [`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
(no agent):

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(llm)
```

Send a message and check whether the model wants to call tools:

```ruby
res = ctx.talk "What's the weather in Tokyo?"

if ctx.pending_functions?
  puts "Model requested #{ctx.pending_functions.size} tool(s)"
else
  puts res.text
end
```

### Executing

When the model asks to call tools, call `ctx.wait(:strategy)` to run
them. `ctx.wait` picks up pending functions, spawns them, waits for
results, and records them back in the context. Every strategy is
supported: `:sequential`, `:thread`, `:fiber`, `:async`, `:fork`,
and `:ractor`.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(llm)

ctx.talk("What's the weather in Tokyo?")
ctx.talk ctx.wait(:thread)
```

### Per-tool confirmation

Because `pending_functions` returns a regular array, you can inspect
each function before execution. Call `ctx.wait(:thread)` to execute
all pending tools, but you can also selectively exclude functions or
run individual ones through `fn.task(:thread).wait` for ad-hoc execution
that bypasses guards and streaming hooks:

```ruby
results = ctx.pending_functions.map do |fn|
  print "Run #{fn.name} with #{fn.arguments}? [y/N] "
  if $stdin.gets&.match?(/\Ay\z/i)
    fn.task(:thread).wait
  else
    fn.cancel(reason: "user declined")
  end
end
ctx.talk(results)
```

This pattern is what
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)'s
built-in confirmation feature uses internally, but doing it manually
gives you full control. Route the decision through a web socket, a
background job, or a multi-user approval flow.

### Full loop

A complete manual tool loop looks like this:

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(llm)
res = nil

loop do
  res = ctx.talk("What's the weather in Tokyo?")
  break unless ctx.pending_functions?

  results = ctx.wait(:thread)
  ctx.talk(results)
end

puts res.content
```

The loop exits when the model responds with text rather than tool
calls. You can extend it with timeouts, user confirmation gates, or
custom error handling for each tool.

### Trade-offs

Manual control is more code but gives you:

- **Arbitrary pre-execution checks**: inspect, rewrite, or skip tool
  calls before they run.
- **Custom confirmation flows**: async approval over HTTP, Slack,
  or email instead of the built-in terminal prompt.
- **Different strategies per tool**: run one tool on a thread and
  another in a forked process within the same turn.
- **Fine-grained error recovery**: rescue per-tool failures and
  decide which results to feed back.

[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html) handles
all of this automatically and is the right choice for most applications.
Drop down to the manual loop when you need control that the agent
abstraction doesn't expose.

## Skills

### Overview

A skill is a markdown file that becomes a tool. When the
model calls that tool, the runtime spawns a subagent.
The subagent gets its own system prompt (the skill body),
its own tool set (from the frontmatter), and a slice of
recent parent context. It runs one turn and returns the
result, then is discarded.

This gives you a supervisor/worker architecture with a
single parent agent. The parent decides when to delegate
work, the skill handles it with focused instructions and
limited tools, and the parent evaluates the result. You
get isolation without complexity.

### How it works

You have one parent agent, zero or more skill files. Each
skill is registered as a tool the model can call.

When the model calls a skill, a subagent is created with:

* **Its own system prompt** -- the body of your SKILL.md
* **Limited tools** -- only what you declare in the frontmatter
* **Context awareness** -- the last 8 user/assistant messages from
  the parent (tool calls stripped)

The subagent runs one turn and returns. The parent sees the
result like any other tool return and decides what to do next.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, skills: ["./skills/git-log", "./skills/deploy"])
agent.talk "Review the recent commits, then deploy if everything looks clean"
```

### Why this matters

Because each skill spawns a fresh subagent with constrained
tools, you can build a clear hierarchy:

**The parent supervises.** It decides which skill to call,
inspects the result, and can iterate or compose multiple
skills together. The parent stays in control.

**Each skill is focused.** Give a skill a narrow prompt and
only the tools it needs. A changelog skill gets `git-log`
and `write-file`, not the shell. A deploy skill gets
deployment tools, not file readers. The less a subagent
has, the less it can wander.

**Skills are stateless.** Every call is independent. No
carryover, no cross-contamination. If a subagent produces
garbage, the parent tries again or moves on.

### Frontmatter

Every skill file begins with YAML frontmatter that sets the
skill's identity and tool access. The markdown body that
follows the frontmatter becomes the subagent's system prompt.

| Field | Purpose |
|---|---|
| `name` | A short identifier for the skill. Used as the tool name. |
| `description` | Explains to the model what the skill does. Used as the tool description. |
| `tools` | Controls what the subagent can call. See the table below. |

The `tools` field accepts four forms. Use `inherit` when the
skill should operate with the same capabilities as the parent.
Use an explicit list to restrict the subagent to only the tools
it needs. The fewer tools a subagent has, the less it can wander.

| Value | Behavior |
|---|---|
| `inherit` | Copies the parent agent's tools, excluding other skills. |
| `all` or `"*"` | Every tool in the global registry. |
| `['name1', 'name2']` | Only the named tools. Raises an error if not found. |
| (omitted) | No tools at all. |

[Back to top](#table-of-contents)

## MCP

#### stdio

The stdio transport connects to an MCP server that is launched as a
separate process, and both its standard input and standard output
streams are used for communication. It is recommended but not
required to execute commands for a stdio transport over a
persistent session via the
[`LLM::MCP#session`](https://r.uby.dev/api-docs/llm.rb/LLM/MCP.html#session-instance_method)
method, otherwise
you could end up launching the same process multiple times.

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
mcp   = LLM::MCP.stdio(argv: ["npx", "-y", "@forgejo/mcp-server"])
agent = LLM::Agent.new(llm)

mcp.session do
  agent.talk "What's happening on forgejo?", tools: mcp.tools
end
```

#### http

The http transport connects to an MCP server over HTTP, and unlike
the stdio transport, the MCP server does not have to be running
locally. Popular services like GitHub provide their own MCP server
over HTTP, and it is one of the most capable MCP servers I have
used.

Unlike the stdio transport,
[`LLM::MCP#session`](https://r.uby.dev/api-docs/llm.rb/LLM/MCP.html#session-instance_method)
carries little benefit for the http transport and it can be
omitted.  It is recommended to consider the `net_http_persistent`
transport for MCP interactions that run over HTTP, otherwise
you could end up tearing down and setting up the same connection
multiple times.

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
mcp   = LLM::MCP.http(
  url: "https://api.githubcopilot.com/mcp/",
  headers: {
    "Authorization" => "Bearer #{ENV.fetch('GITHUB_PAT')}"
  },
  transport: :net_http_persistent
)
agent = LLM::Agent.new(llm)
agent.talk "What's happening on GitHub?", tools: mcp.tools
```

[Back to top](#table-of-contents)

## A2A

#### rest

The rest transport communicates with other agents via A2A
endpoints that speak both HTTP and JSON. The skills advertised
by an agent become subclasses of
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html)
that can be used by both
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html),
and [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
, similar to how MCP tools become subclasses of
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html).

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
a2a   = LLM::A2A.rest(url: "https://agent.example.com")
agent = LLM::Agent.new(llm, tools: a2a.skills)
agent.talk "What's happening, fellow agent?"
```

#### jsonrpc

The jsonrpc transport communicates with other agents via HTTP
and a protocol known as jsonrpc. Sometimes an agent will
implement both, or just one of each. An agent's card, which
is represented by an instance of
[`LLM::A2A::Card`](https://r.uby.dev/api-docs/llm.rb/LLM/A2A/Card.html),
can be
used to discover available transports via the
[`LLM::A2A::Card#interfaces`](https://r.uby.dev/api-docs/llm.rb/LLM/A2A/Card.html#interfaces-instance_method)
method.

```ruby
require "llm"
llm   = LLM.deepseek(key: ENV["KEY"])
a2a   = LLM::A2A.jsonrpc(url: "https://agent.example.com")
agent = LLM::Agent.new(llm, tools: a2a.skills)
agent.talk "What's happening, fellow agent?"
```

[Back to top](#table-of-contents)

## Transports

The [`LLM::Provider`](https://r.uby.dev/api-docs/llm.rb/LLM/Provider.html),
[`LLM::MCP`](https://r.uby.dev/api-docs/llm.rb/LLM/MCP.html), and
[`LLM::A2A`](https://r.uby.dev/api-docs/llm.rb/LLM/A2A.html) classes
all accept a `transport` option that decides which library
will be used for HTTP communication. There are three options out
of the box:
[`net-http`](https://github.com/ruby/net-http),
[`net-http-persistent`](https://github.com/drbrain/net-http-persistent),
and [`curb`](https://github.com/taf2/curb).

#### net/http

The [`net/http`](https://github.com/ruby/net-http) transport is represented by the symbol `:net_http`. <br>
It is the default transport.

```ruby
require "llm"

llm = LLM.deepseek(key: "...", transport: :net_http)
mcp = LLM::MCP.http(url: "...", transport: :net_http)
a2a = LLM::A2A.rest(url: "...", transport: :net_http)
```

#### net/http/persistent

The [`net/http/persistent`](https://github.com/drbrain/net-http-persistent) transport is represented by the symbol `:net_http_persistent`. <br>
It maintains a connection pool so the cost of tearing down and
setting up a connection repeatedly is kept low, and it is built
on top of [`net/http`](https://github.com/ruby/net-http).

```ruby
require "llm"

llm = LLM.deepseek(key: "...", transport: :net_http_persistent)
mcp = LLM::MCP.http(url: "...", transport: :net_http_persistent)
a2a = LLM::A2A.rest(url: "...", transport: :net_http_persistent)
```

#### curb

The [`curb`](https://github.com/taf2/curb) transport is represented by the symbol `:curb`. <br>
It provides bindings for libcurl, a widely used, highly portable
and feature-rich HTTP library written in C.

```ruby
require "llm"

llm = LLM.deepseek(key: "...", transport: :curb)
mcp = LLM::MCP.http(url: "...", transport: :curb)
a2a = LLM::A2A.rest(url: "...", transport: :curb)
```

[Back to top](#table-of-contents)

## Stream

#### IO-like object

Any object that implements the `#<<` method can receive
chunks from a stream. That includes objects like `$stdout`.
This form of streaming is simple and limited. It is the
equivalent of
[`LLM::Stream#on_content`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_content-instance_method),
and doesn't include
any of the other
[`LLM::Stream`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html)
hooks.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, stream: $stdout)
agent.talk "hello world"
```

#### LLM::Stream

The [`LLM::Stream`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html)
class provides many hooks that a subclass
can implement. They range from being notified when a tool call
starts to when a tool call finishes, or when a conversation is
due to be compacted because the context window exceeded a defined
limit. All these callbacks support a responsive user interface
where the user is always aware of what is happening behind the
scenes.

```ruby
class Stream < LLM::Stream
  def on_content(content)
    puts content
  end

  def on_reasoning_content(content)
    puts content
  end

  def on_tool_call(tool)
    # this callback can be used to either log a tool call,
    # or execute a tool call during a stream.
  end

  def on_tool_return(tool, result)
  end

  def on_compaction(compactor)
    # this callback is called *before* a compact happens
  end

  def on_compaction_finish(compactor)
    # this callback is called *after* a compact happens
  end
end
```

[Back to top](#table-of-contents)

## Concurrency

llm.rb supports six concurrency strategies for tool execution:
`:sequential`, `:thread`, `:fiber`, `:async`, `:fork`, and `:ractor`.
Each one implements the same interface (`spawn`, `wait`, `alive?`,
`interrupt!`), so the caller never has to care which strategy is
behind a given task.

Choose a strategy per-agent or per-call:

```ruby
## Per-agent: every tool loop uses :fork
agent = LLM::Agent.new(llm, concurrency: :fork, tools: [...])

## Per-call: run a single tool on a thread
fn = FetchStocks.function
fn.task(:thread).wait
```

Interruption is reliable across all six. No matter the backing (thread, fiber, process, ractor),
`LLM::Interrupt` reaches the
tool and it can rescue, clean up, and either re-raise to cancel the
turn or return a value to continue.

#### sequential

The default. Tools run one at a time on the calling thread. No
concurrency, no overhead. `spawn` is a no-op. Execution happens
in `wait`. `alive?` always returns `false`.

Best for simple agents with a tool or two, debugging, or when tool
order matters.

#### thread

Each tool runs in its own `Thread`. The thread is created lazily.
You can build a task, pass it around, and decide when to run it.
Threads have `report_on_exception` disabled so errors surface through
`wait` rather than stderr.

Interruption raises `LLM::Interrupt` directly on the tool's thread,
which stops it mid-flight.

Best for IO-bound tools: HTTP calls, database queries. CRuby
releases the GVL during blocking IO, so you get real concurrency.

#### fiber

Each tool runs in a scheduler-backed `Fiber` via `Fiber.schedule`.
Requires `Fiber.scheduler`. Raises `ArgumentError` without one.
Fibers yield cooperatively at IO boundaries, so this pairs well with
async libraries that set a scheduler.

Interruption raises `LLM::Interrupt` on the fiber, which stops at
the next yield point.

Best for IO-bound tools inside an async framework. Much lighter than
threads.

#### async

Each tool runs as an `Async::Task` inside a managed background
reactor. A dedicated thread runs an `Async::Reactor` event loop.
Work is submitted through a thread-safe `Queue` inbox and consumed
by the reactor. All fibers stay on one thread. No shared-memory
contention between them.

The reactor is created on demand and shared across all tasks in a
group. When `Group#wait` is called, tasks are submitted, the reactor
runs them concurrently, and results are bridged back to the caller
through per-task queues. The reactor is torn down after `wait`
completes.

Interruption pushes an `LLM::Interrupt` sentinel into the task's
result queue instead of using `Fiber#raise`. This is cleaner and
avoids surprising the reactor's internal fibers.

Best for IO-bound tools when you want Async's structured concurrency
model without running your whole application inside a reactor. The
reactor is self-contained. Your main thread stays synchronous.
Requires the `async` gem.

#### fork

Each tool runs in a forked child process. Communication uses
[`xchan`](https://github.com/1robertrb/xchan.rb) (marshal-based
channels): the parent sends control messages, the child sends
results back. Each child is a separate OS process with its own
memory space. A crash in the tool cannot touch the parent.

`Fork::Task` checks liveness with `Process.waitpid(WNOHANG)` and
delivers interrupts as messages over the control channel. The child
raises `LLM::Interrupt` on `Thread.main` when it receives the
interrupt message. Tracer callbacks fire in both parent and child.

Best for process isolation: shell commands, native extensions,
anything you don't want touching the parent's memory. True parallelism
too, since there's no GVL in separate processes. Requires the
`xchan` gem.

#### ractor

Each class-based tool runs in a Ruby `Ractor`. `Ractor::Task`
coordinates through `Ractor::Mailbox`. Interruption sends a message
through the mailbox; a listener thread inside the ractor raises
`LLM::Interrupt` on `Thread.main`.

Ractors have restrictions: only class-based tools are supported (no
blocks, skills, or MCP tools), and arguments must be
ractor-shareable. The runtime raises `LLM::RactorError` early if
you try to run an unsupported tool type.

Best for CPU-bound tools, true parallelism without the overhead of
forking full processes. More restrictive than `:fork` but lighter.

#### Quick reference

| Strategy | Backing | Parallel? | Isolation? | Requires |
|---|---|---|---|---|
| `:sequential` | direct call | No | No | None |
| `:thread` | `Thread` | IO only (GVL) | No | None |
| `:fiber` | `Fiber.schedule` | Cooperative | No | `Fiber.scheduler` |
| `:async` | `Async::Reactor` on bg thread | Cooperative | No | `async` gem |
| `:fork` | `Kernel.fork` | Yes (process) | Yes (memory) | `xchan` gem |
| `:ractor` | `Ractor` | Yes (CPU) | Limited | None |

[Back to top](#table-of-contents)

## Context Compaction

Long-running conversations consume tokens. Without intervention, every turn
pushes toward the model's context window limit, at which point the provider
rejects the request.

llm.rb provides compaction through pluggable strategies. All strategies
inherit from [`LLM::Compactor`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor.html)
and are invoked automatically before each `ctx.talk(...)` call.

### Configuration

Pass a compactor class and options when creating a context or agent:

```ruby
ctx = LLM::Context.new(
  llm,
  compactor: LLM::Compactor::Truncate,
  compactor_options: {keep: 64}
)

# LLM::Agent accepts the same options
agent = LLM::Agent.new(
  llm,
  compactor: LLM::Compactor::Truncate,
  compactor_options: {keep: 128}
)
```

The compactor runs automatically before every `talk` call. This keeps the
conversation constantly alive. There is no chance of exhausting the context
window because old messages are dropped before they accumulate. The trade-off
is that dropped messages are gone, so information may be lost. Set `keep` to
a higher number to retain more context at the cost of slower accumulation.

The default is [`LLM::Compactor::Null`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Null.html)
Compaction is disabled unless you opt in.

### Standalone usage

A compactor can be used independently of a context or agent:

```ruby
compactor = LLM::Compactor::Truncate.new(agent)
compactor.call(keep: 200)   # or ctx, agent, etc.
```

This is useful for one-off compaction outside the automatic per-turn cycle,
or when you want to compact on a different schedule.

### Strategies

**[`LLM::Compactor::Null`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Null.html)**
. The default. Does nothing.

**[`LLM::Compactor::Truncate`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Truncate.html)**
Drops the oldest messages, keeping only the N most recent.

- **Fast**: no network call, no LLM overhead. Operates entirely in memory
  with a single pass over the message list.
- **No dependencies**: works offline, has no model or API requirements, and
  introduces no additional cost.
- **Tool-loop safe**: when a tool result (return) falls at the truncation
  boundary, the corresponding tool call is kept. Without this, the
  conversation would contain an orphaned result with no matching call,
  causing API-level errors on the next turn.

The `keep:` parameter accepts either an integer count or a percentage
string like `"80%"`, which keeps approximately 80% of the most recent
messages. This is useful when you want to trim proportionally rather
than to an absolute number.

```ruby
ctx = LLM::Context.new(
  llm,
  compactor: LLM::Compactor::Truncate,
  compactor_options: {keep: 128}
)
```

### Manual compaction

The REPL provides a `/compact` command that invokes Truncate on the current
agent's context:

```
/compact        # keep last 128 messages
/compact 50     # keep last 50 messages
/compact 75%    # keep approximately 75% of messages
```

### Lifecycle callbacks

Both strategies call stream hooks so the UI can show progress:

```ruby
def on_compaction(compactor)
  # called before compaction begins
end

def on_compaction_finish(compactor)
  # called after compaction completes
end
```

The context's `compacted?` flag is `true` between compaction and the next
model response.

[Back to top](#table-of-contents)

## Serialization

The [`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
class can be serialized to JSON and stored in a string or on disk.
That is powerful because a context contains runtime state that can
be restored later, in a different process or even on a different
machine. And because an agent is implemented on top of
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
this feature works for [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html),
too.

#### Save to disk

The runtime can serialize its state to a string, a text file, or
a database column. The option that fits best depends on your application
and environment. Web applications might be more interested in the [ORM](#orm)
feature, which is built on top of the serialization feature.

```ruby
##
# Create a provider
llm = LLM.deepseek(key: ENV["KEY"])

##
# Save agent
agent1 = LLM::Agent.new(llm)
agent1.talk "remember my name is robert"
agent1.save(path: "agent.json")

##
# Restore agent
agent2 = LLM::Agent.new(llm, stream: $stdout)
agent2.restore(path: "agent.json")
agent2.talk "what's my name?"
```

## ORM

Both ActiveRecord, and Sequel have first-class support on the
llm.rb runtime. In both cases an ActiveRecord or Sequel model
can be turned into a model that has the same capabilities as
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html),
or [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html).

The main difference is that the runtime persists directly into
the database with no requirements beyond a single column on a
single row. That means it is usually trivial to turn an existing
model into an AI-aware model.

#### ActiveRecord

The ActiveRecord interface for
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
is
[`acts_as_agent`](https://r.uby.dev/api-docs/llm.rb/LLM/ActiveRecord/ActsAsAgent.html).
It yields an instance of
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html),
and that can be used
to configure the agent (eg which model, instructions, skills,
tools, etc).

An interesting option is the `format` option, by default it
defaults to `:string` but it can also be changed to `:json`
or `:jsonb` depending on the configuration and type of underlying
column. The JSONB column type is recommended.

```ruby
require "active_record"
require "llm"
require "llm/active_record"

class Agent < ApplicationRecord
  acts_as_agent(format: :jsonb) do |agent|
    agent.model "deepseek-v4-pro"
    agent.instructions "solve the user's query"
    agent.tools [Research, FinalizeResearch, ActOnResearch]
  end

  private

  ##
  # By convention, this method defines the provider
  # for a model. If neccessary, it can be renamed and
  # configured via `provider: :your_method` instead.
  def set_provider
    LLM.deepseek(key: ENV["KEY"])
  end

  ##
  # By convention, this method should return what is
  # given as the second argument to `LLM::Context` or
  # `LLM::Agent`.
  #
  # Often, there is no need to set it, so it can be left
  # undefined or it can be reassigned in the same way as
  # `set_provider`. For example: `context: :your_method`
  def set_context
    {}
  end
end

agent = Agent.create!
agent.talk "perform research"
```

#### Sequel

The following is a Sequel equivalent to the ActiveRecord example,
but to keep it interesting and informative, this example also
configures a per-model tracer that logs to `$stdout`. Works the
same for ActiveRecord.

```ruby
require "sequel"
require "llm"
require "llm/sequel/plugin"

class Agent < Sequel::Model
  plugin(:agent, format: :jsonb) do |agent|
    agent.model "deepseek-v4-pro"
    agent.instructions "solve the user's query"
    agent.tools [Research, FinalizeResearch, ActOnResearch]
    agent.tracer { LLM::Tracer::Logger.new(llm, io: $stdout) }
  end

  private

  def set_provider
    LLM.deepseek(key: ENV["KEY"])
  end
end

agent = Agent.create
agent.talk "perform research"
```

[Back to top](#table-of-contents)

## Schema

The [`LLM::Schema`](https://r.uby.dev/api-docs/llm.rb/LLM/Schema.html)
class can be subclassed to describe
the shape of a JSON object or objects that you expect
the model to respond with.

It can be useful for a wide range of use cases but the
most popular might be classification, data extraction,
and transferring structured data between different software
rather than blobs of text that a machine cannot easily parse
in a structured way.

#### Estimation

The following example asks the model to estimate the age
of a person in a photo. The model provides a structured response
that's represented by an instance of
[`LLM::Object`](https://r.uby.dev/api-docs/llm.rb/LLM/Object.html).

The object returned by
[`LLM::Response#content!`](https://r.uby.dev/api-docs/llm.rb/LLM/Contract/Completion.html#content!-instance_method)
has methods that can access the age, confidence, and comments
properties.
This approach can also work for extracting data or an analysis
from a PDF, and other file types.

```ruby
require "llm"
require "pp"

class Estimation < LLM::Schema
  property :age, Integer, "The estimated age of the person"
  property :confidence, Number, "Your confidence in the estimate"
  property :applicable, Boolean, "True when the photo contains a person"
  property :comments, String, "Any additional comments or input"
  required %i[age confidence applicable comments]
end

llm = LLM.openai(key: ENV["KEY"])
agent = LLM::Agent.new(llm, schema: Estimation)
res = agent.ask "Given this photo, provide an age estimate", with: "photo.jpg"

##
# Coerces the model's response from a JSON string
# to an instance of LLM::Object.
estimate = res.content!

##
# Let's print the estimate
if estimate.applicable
  print "The person is approx ", estimate.age.to_s, " years old", "\n"
  print "I have a confidence rating of ", estimate.confidence.to_s, "\n"
else
  print "This photo is not applicable:", "\n"
  print estimate.comments
end
```

[Back to top](#table-of-contents)

## Cancellation

#### Cancel a request

A common scenario when communicating with a model is to
want to cancel the request mid-stream. This could be done
for a number of different reasons, most often because the
user made a mistake, or the model is making a mistake and
the user wants to cancel the action.

The runtime has built-in support for cancellation. Call
`agent.cancel!` or `ctx.cancel!` from any thread and two
things happen at once:

[`LLM::Interrupt`](https://r.uby.dev/api-docs/llm.rb/LLM/Interrupt.html)
is raised on the thread where `talk` is running, so the
caller can rescue it and know the request was cancelled.

At the same time, `LLM::Interrupt` is raised on every tool
that is currently executing, regardless of which
concurrency strategy it's using. A tool running in a thread
gets it on that thread. A tool in a fiber gets it on that
fiber. A tool in a forked process gets it via a message
over the xchan control channel. The
delivery mechanism depends on the strategy, but the effect is
the same: the tool can rescue `LLM::Interrupt`, clean up
resources, close connections, flush buffers, and either
re-raise to abort or return a partial result.

Pending tools (those the model requested but that haven't
started running yet) are cancelled through
[`LLM::Function#cancel`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#cancel-instance_method)
without ever being executed.

The transport layer also cancels the in-flight HTTP request,
closing the connection to the provider.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
agent = LLM::Agent.new(llm)
queue = Queue.new

Thread.new do
  queue.push(nil)
  sleep(2)
  agent.cancel!
end

begin
  queue.pop
  agent.talk "write me a very long poem", stream: $stdout
rescue LLM::Interrupt
  puts "request cancelled!"
end
```

#### Tool interrupts

When a running tool is interrupted, for example the user presses
ESC in the [REPL](#repl), the runtime raises
[`LLM::Interrupt`](https://r.uby.dev/api-docs/llm.rb/LLM/Interrupt.html)
on the tool's execution context. This behavior is uniform across
all six concurrency strategies (`:sequential`, `:thread`, `:fiber`,
`:async`, `:fork`, and `:ractor`).

A tool has two choices:

**Re-raise** `LLM::Interrupt` to cancel the entire turn. The
exception propagates out of the tool loop and the request is
aborted. This is the default when you don't rescue the exception.

```ruby
def call
  # ... do work ...
rescue LLM::Interrupt
  cleanup
  raise   # cancel the turn
end
```

**Return a value** to continue the tool loop. The model receives
the result and decides what to do next, aware that the tool was
interrupted.

```ruby
def call
  # ... do work ...
rescue LLM::Interrupt
  cleanup
  {ok: false, reason: "interrupted"}  # continue the loop
end
```

The right choice depends on the situation. A hard cancel aborts
the request outright. Useful when continuing would produce
garbage. Returning a value lets the model adapt, which can be
helpful when the interrupt is temporary (e.g. a timeout).

The `:ractor` strategy delivers the interrupt through ractor
message passing. A listener thread inside the tool ractor
receives the interrupt message and raises `LLM::Interrupt` on the
ractor's main thread. The end result is the same as every other
strategy: the tool can rescue, clean up, and decide.
The `:fork` strategy delivers the interrupt via a message
over the xchan control channel, which a listener thread in the
child process picks up and raises on `Thread.main`. All other strategies
raise the exception directly on the executing thread or fiber.

[Back to top](#table-of-contents)

## Tracer

The runtime can be observed by subclasses of
[`LLM::Tracer`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer.html). <br>
The default tracers include a tracer that can write to standard
output
([`LLM::Tracer::Logger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Logger.html)),
and a generic OpenTelemetry tracer that can export spans via OTLP
([`LLM::Tracer::Telemetry`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Telemetry.html)).

llm.rb has numerous hooks implemented throughout the runtime that
[`LLM::Tracer`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer.html)
subclasses can hook into, and the tracer is
purposefully designed to be extensible. The scope of a trace
can vary from an individual agent (an instance of
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)),
or for every request a provider makes (an indirect instance of
[`LLM::Provider`](https://r.uby.dev/api-docs/llm.rb/LLM/Provider.html)).

#### Provider-wide tracer

The following two examples demonstrate provider-wide tracers that
cover every request made for a single provider.

```ruby
##
# Provider-wide tracer
# Writes to $stdout
llm = LLM.deepseek(key: ENV["KEY"])
llm.tracer = LLM::Tracer::Logger.new(llm, io: $stdout)

##
# Provider-wide tracer
# Writes to deepseek.log
llm = LLM.deepseek(key: ENV["KEY"])
llm.tracer = LLM::Tracer::Logger.new(llm, path: "deepseek.log")
```

#### Agent-local tracer

The next two examples demonstrate a tracer that is local
to an agent.

```ruby
##
# Agent-local
# Writes to $stdout
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tracer: LLM::Tracer::Logger.new(llm, io: $stdout))

##
# Agent-local
# Writes to deepseek-agent.log
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tracer: LLM::Tracer::Logger.new(llm, path: "deepseek-agent.log"))
```

[Back to top](#table-of-contents)

## REPL

During the development and operation of agents it can often
be helpful to drop into a read-eval-print loop. This gives
you a way to confirm the work was successful, inspect
anything that went wrong, and keep talking to the same
agent while its state is still intact.

The REPL is a curses-based TUI with a status line showing
a context-usage bar and cost counter, a scrollable transcript
that renders markdown, and a multi-line input area. The UI
thread stays responsive while a second thread communicates
with the model.

#### LLM::Agent

The [LLM::Agent#repl](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#repl-instance_method)
method allows an agent to spawn a read-eval-print loop
that can be useful while developing or operating agents.
It can be used to debug tool calls, confirm an
agent has done what was expected, or improve an agent by
asking questions about what it has done up to that point.

This feature requires that the [curses](https://github.com/ruby/curses)
and [kramdown](https://github.com/gettalong/kramdown) libraries are
installed and available to require.

The `name:` option labels the agent throughout the TUI.
Useful when working with multiple agents. The `path:` option
persists state across sessions. The `tools:` option attaches
extra tools for the duration of the session.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, name: "my-agent")
agent.repl(path: "session.json", tools: LLM::Tool.subclasses)
```

#### Persistence

The `path:` option accepts a file path where runtime state
is read from and written to. This lets you resume a
conversation across REPL sessions. When the file does not
exist the agent starts fresh; when it does, the agent
restores its previous state.

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm)
agent.repl(path: "session.json")
```

#### Tools

The read-eval-print loop accepts a `tools` option that lets
you attach additional tools for the duration of the session.

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm)
agent.repl(tools: [Debugger])
```

Load every built-in tool with `LLM::Tool.subclasses`:

```ruby
require "llm/tools"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm)
agent.repl(tools: LLM::Tool.subclasses)
```

#### Skills

The read-eval-print loop also accepts a `skills` option.
This can be useful when you want to load extra skills
without attaching them to an agent permanently.

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm)
agent.repl(skills: [__dir__])
```

#### Tracer

By default the tracer is disabled for the duration of the
session. This can be configured through the
`tracer` option. Setting it to `true` will configure
the REPL to use the tracer associated with an instance
of [`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html).

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tracer: LLM.logger(llm, path: "agent.log"))
agent.repl(tracer: true, tools: [Debugger])
```

#### Input

The input area supports several keyboard shortcuts.
When characters arrive faster than a threshold the REPL
detects that text is being pasted rather than typed. In
paste mode pressing `Enter` inserts a newline instead of
submitting, allowing multi-line prompts.

| Key | Action |
|---|---|
| `Enter` | Submit the current prompt |
| `Ctrl+A` | Jump to the start of the line |
| `Ctrl+E` | Jump to the end of the line |
| `Ctrl+F` | Move the cursor forward |
| `Ctrl+K` | Erase from cursor to the end of the line |
| `Ctrl+Y` | Paste previously killed text |
| `Ctrl+D` | Delete the character at the cursor |
| `Ctrl+P` | Recall the previous user message |
| `Ctrl+N` | Recall the next user message |
| `Left / Right` | Move the cursor |
| `Up / Down` | Scroll the transcript one line |
| `PgUp` / `PgDn` | Scroll the transcript by one page |
| `Tab` | Complete `/command` names |
| `Esc` | Cancel the current request |

#### Commands

Commands are recognized by a `/` prefix on the input line.
Type `/compact` to free context window space by dropping the
oldest messages. Type `/exit` to leave the REPL.

The [`LLM::Repl::Command`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Command.html)
class is intentionally similar to [`LLM::Tool`](#llmtool) and
[`LLM::Schema`](#schema) in its interface. You declare a
name, description, and parameters with the same vocabulary.
A subclass is automatically registered and available as `/name`.

##### Parameters

Parameters are declared with `parameter :name, Type, "description"`
and marked required with `required %i[name]`. The `call` method
receives them as keyword arguments matching the parameter names.
Parameters without a user-supplied value fall back to the
method signature's default.

```ruby
class Greeter < LLM::Command
  name "greet"
  description "Greets the given name"
  parameter :name, String, "The person's name"
  required %i[name]

  def call(name:)
    write "Welcome #{name}!\n"
  end
end
```

##### Output

A command writes to the transcript with `write(str, who:)`.
The `who:` label is rendered in bold. It defaults to
`command(name): ` where `name` is the command's registered
name.

```ruby
def call(name:)
  write("Greetings #{name}!\n")
end
```

##### Help

The built-in [`help`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Command.html#help-class_method)
class method formats the name, description, and parameter list
automatically. Use it from inside a command or via `/help`.

```ruby
class Greeter < LLM::Command
  name "greet"
  # ...
end

# /help greet displays:
#   Command: greet
#   Description: Greets the given name
#
#   Parameters:
#     name [String] - The person's name (required)
```

##### Aliases

Subclassing an existing command inherits its name, description,
and parameters. This is how `/quit` is an alias of `/exit`:

```ruby
class Quit < LLM::Repl::Command::Exit
  name "quit"
end
```

[Back to top](#table-of-contents)

## Images

The OpenAI, Google, xAI, DeepInfra, and DeepSeek providers have
builtin image generation capabilities. OpenAI, xAI, and DeepInfra
also support image edits. Google only supports image generation.
DeepSeek supports generation and edits too, but only through SVG
output rather than raster image models.

#### Generation

The [`LLM::Provider#images`](https://r.uby.dev/api-docs/llm.rb/LLM/Provider.html#images-instance_method)
method returns an Image
object that a subset of providers implement. At the
moment Google, xAI, OpenAI, DeepInfra, and DeepSeek have image
generation capabilities. DeepSeek is the odd one out: it generates
SVG documents rather than raster images.

```ruby
require "llm"

##
# Store dogrocket.png
llm = LLM.openai(key: ENV["KEY"])
res = llm.images.create(prompt: "a dog on a rocket to the moon")
IO.copy_stream res.images[0], "dogrocket.png"
```

The API is the same across providers. <br>
For example, xAI:

```ruby
require "llm"

##
# Store dogrocket.png
# Same API as OpenAI
llm = LLM.xai(key: ENV["KEY"])
res = llm.images.create(prompt: "a dog on a rocket to the moon")
IO.copy_stream res.images[0], "dogrocket.png"
```

#### Edits

OpenAI, xAI, and DeepInfra have the same interface for image edits. <br>
DeepSeek also supports edits, but only for SVG files. <br>
Google does not have edit image support. <br>

```ruby
require "llm"

##
# Edit self.jpg and add a mustache
# Save to mustache.png
llm = LLM.openai(key: ENV["KEY"])
res = llm.images.edit(prompt: "add a mustache", image: "self.jpg")
IO.copy_stream res.images[0], "mustache.png"
```

#### DeepSeek

The DeepSeek provider does not provide an image generation model
but it is possible to ask a text-to-text model to produce
vector graphics (SVGs), and in that limited sense, it can become
a capable text-to-image model.

```ruby
require "llm"

##
# Edit rocket.svg and change its color
# Save to rocket-edited.svg
llm = LLM.deepseek(key: ENV["KEY"])
res = llm.images.edit(prompt: "make the rocket red", image: "rocket.svg")
IO.copy_stream res.images[0], "rocket-edited.svg"
```

An interesting property of the DeepSeek implementation is that
it can maintain a session that can perform multiple image generations
or edits rather than just one-shot generations.

It's possible because under the hood
[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html),
is attached to the
[`LLM::Response`](https://r.uby.dev/api-docs/llm.rb/LLM/Response.html)
object that is returned to the caller. So the response includes an
`agent` method, and it can be carried across multiple generations.
It is specific to this endpoint though. It works like this:

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
agent = nil
loop do
  print "> "
  prompt = $stdin.gets
  res = llm.images.create(prompt:, agent:)
  agent = res.agent
  IO.copy_stream res.images[0], "image.svg"
  print "ok: saved image.svg", "\n"
end
```

[Back to top](#table-of-contents)

## Audio

The audio interface defined by llm.rb describes three methods,
although not every provider implements all of them. Generally
speaking the audio interface is for text-to-speech, and
speech-to-text models.

The following providers have audio support:

* OpenAI - full support
* Google - partial support
* DeepInfra - partial support

#### text-to-speech

The `create_speech` method generates an audio clip based
on the given input. This method returns a
[`LLM::URIData`](https://r.uby.dev/api-docs/llm.rb/LLM/URIData.html)
object. OpenAI, and DeepInfra support this method.

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.audio.create_speech(input: "Hello world")
IO.copy_stream res.audio.decoded, "helloworld.mp3"
```

#### speech-to-text

The `create_transcription` method transcribes a given
audio clip as text. OpenAI, Google and DeepInfra support
this method.

```ruby
require "llm"

llm = LLM.google(key: ENV["KEY"])
res = llm.audio.create_transcription(file: "helloworld.mp3")
res.text # => "Hello world"
```

#### translation

The `create_translation` method translates a given audio
clip, then transcribes it as text. OpenAI, and Google
support this method.

```ruby
require "llm"

llm = LLM.google(key: ENV["KEY"])
res = llm.audio.create_translation(file: "bomdia.mp3")
res.text # => "Good day"
```

[Back to top](#table-of-contents)

## OCR

Optical Character Recognition extracts text from images and
documents.

#### Mistral

Mistral is the only provider that currently supports OCR
through its dedicated API endpoint. The `ocr` method accepts
either an `image_url:` or a `document_url:` parameter.
Document URLs can point to PDFs. The response exposes pages
through `res.pages`, where each page has a `markdown` field
containing the extracted text.

```ruby
require "llm"

llm = LLM.mistral(key: ENV["KEY"])

##
# Extract text from an image
res = llm.ocr(image_url: "https://example.com/photo.png")
res.pages.each { |page| puts page.markdown }

##
# Extract text from a PDF
res = llm.ocr(document_url: "https://example.com/report.pdf")
res.pages.each { |page| puts page.markdown }
```

[Back to top](#table-of-contents)
