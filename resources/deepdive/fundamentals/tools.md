
## Tools

### Introduction

#### Overview

A tool is how a model reaches outside its own head. Without tools,
the model can only produce text. With a tool, it can run a shell
command, query a database, or fetch a web page. The model decides
when a tool fits the request; the runtime calls it and sends the
result back.

A tool is a Ruby class with a name, a description, and a
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call)
method. The name tells the model what the tool is called. The
description tells the model when to use it. The
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call)
method receives the arguments and returns the result. That is the entire
contract: name, description, parameters, and a method that runs.

#### How it works

A tool is a subclass of
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html)
with a name, description, and optional typed parameters. The model sees the name and
description and decides whether to call it. When it does, the
runtime serializes the arguments and passes them to
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call).

Tools that spawn subprocesses can include
[`LLM::Tool::Utils`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Utils.html)
to get shared
[`wait(command:, timeout:)`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool/Utils.html#wait-instance_method)
and `now` help. The built-in `Shell`, `Git`, `Rg`, and `Mkdir` tools
use it to kill a command that exceeds its `timeout`.

If
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call)
raises, the runtime rescues it and returns a structured
error to the model instead. The conversation stays valid. You can
also handle errors yourself inside
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call)
by rescuing and returning a domain-specific error hash.

```ruby
class Shell < LLM::Tool
  set name: "shell",
      description: "execute a shell command",
      parameters: [
        [:name, String, "the command's name", {required: true}],
        [:arguments, Array[String], "command args", {default: []}]
      ]

  def call(name:, arguments: [])
    out = `#{name.shellescape} #{arguments.map(&:shellescape).join(" ")}`
    {ok: $?.success?, out:}
  end
end

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tools: [Shell], stream: $stdout)
agent.talk "What files are in the current working directory?"
```

#### Why would I use it?

Tools are how the model interacts with the outside world, and the
model is the orchestrator. When you give an agent a handful of
tools and ask it to do something open-ended, the model reads each
tool's name and description, chooses which to call, and picks the
arguments. The runtime just executes. The model can chain tools
into a multi-step workflow, retry after a failure, or fan several
calls out in parallel and synthesize the results.

That orchestration is the killer feature. One tool lets the model
reach outside itself; several tools let it plan and execute a
whole job. A single "research the competitors and compare their
pricing" turn can fan out to a web search, a database query, and an
API call at once, then return a synthesized answer. See
[Fan-out with tools](#fan-out-with-tools) below for the pattern.

#### Notes

Confirmation gates tools behind explicit approval. List tool names
in
[`LLM::Agent#confirm`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#confirm)
to block execution until you override
[`LLM::Agent#on_tool_confirmation`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#on_tool_confirmation).
Confirmation also accepts a Symbol that resolves to an instance
method, letting the confirmed set change per-instance based on
runtime conditions.

Tool properties can be defined with individual method calls (as shown
in the How it works section) or with
[`LLM::Tool.set`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#set-class_method)
(see the Set subsection). Both approaches work the same way.

### Confirmation

#### Overview

Tools that perform destructive actions can be gated behind explicit
approval. List their names in
[`LLM::Agent#confirm`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#confirm)
to block execution
until you override
[`LLM::Agent#on_tool_confirmation`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#on_tool_confirmation).
The default handler cancels
the tool. Override it per-agent to prompt the user, log the decision,
or auto-approve certain tools.

#### How it works

When you want to override the default approval flow for a gated
tool, override
[`LLM::Agent#on_tool_confirmation`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#on_tool_confirmation)
on the subclass. The method receives the pending function and the
execution strategy. Call
[`LLM::Function#task`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#task)
to execute the tool or
[`LLM::Function#cancel`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#cancel)
to block it. The default handler cancels the call.

```ruby
class AdminAgent < LLM::Agent
  set confirm: %w[delete destroy shutdown]

  def on_tool_confirmation(fn, strategy)
    print "Run #{fn.name} with #{fn.arguments}? [y/N] "
    $stdin.gets&.match?(/\Ay\z/i) ? fn.task(strategy).wait : fn.cancel
  end
end
```

#### Why would I use it?

Confirmation prevents the model from running dangerous tools
without user oversight. You decide the approval flow: a terminal
prompt, a web socket, a background job queue.

#### Notes

Confirmation names can be a static array of tool names or a Symbol
that resolves to an instance method. The Symbol form lets the
confirmed set change per-instance based on runtime conditions.

### Errors

#### Overview

A tool that raises does not crash the conversation. The runtime
catches the exception, wraps it into a structured error, and
returns it to the model. The model can read the error, decide what
went wrong, and try something else. The tool loop stays alive no
matter what.

#### How it works

If
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call)
raises, the runtime returns `{error: true, type: "RuntimeError",
message: "boom"}` to the model. You can also rescue inside
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call)
and return your own error shape that gives the model more context.

```ruby
class Shell < LLM::Tool
  set name: "shell",
      description: "run a shell command",
      parameters: [
        [:name, String, "the command name", {required: true}],
        [:arguments, Array[String], "command args", {default: []}]
      ]

  def call(name:, arguments: [])
    out = `#{name} #{arguments.join(" ")}`
    {ok: $?.success?, out:}
  rescue Errno::ENOENT
    {ok: false, error: "command not found: #{name}"}
  end
end
```

#### Why would I use it?

Custom error handling gives the model domain-specific detail that
helps it recover. Instead of a generic "RuntimeError: boom", the
model sees `{ok: false, error: "command not found: ls"}` and knows
to correct the command name and try again.

#### Notes

The principle is the same either way: return something. A tool call
must complete with a tool response. If you do not return a value and
you do not raise, the runtime has nothing to send back and the
conversation is stuck.

### Set

#### Overview

[`LLM::Tool.set`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#set-class_method)
is an alternative way to define tool properties using a Hash. It
works the same way as individual method calls and accepts the same
keys: `name`, `description`, `parameters`, `required`, and
`defaults`.

#### How it works

When you want to define tool properties at once, call
[`LLM::Tool.set`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#set-class_method)
with a Hash. The keys match the individual method names. The
`parameters` key accepts the same Array of tuples that the
individual `parameter` method does.

```ruby
class Shell < LLM::Tool
  set name: "shell",
      description: "execute a shell command",
      parameters: [
        [:name, String, "the command's name", {required: true}],
        [:arguments, Array[String], "One or more arguments", {default: []}]
      ]

  def call(name:, arguments: [])
    out = `#{name.shellescape} #{arguments.map(&:shellescape).join(" ")}`
    {ok: $?.success?, out:}
  end
end
```

#### Why would I use it?

`set` is useful when you want to keep related properties together.
Instead of spreading `name`, `description`, `parameters`, and
`required` across multiple lines, you can group them in a single
Hash that reads like a configuration block.

#### Notes

Unknown keys raise `KeyError`, so typos are caught at class load
time rather than at runtime.

### Fan-out with tools

#### Overview

The fastest way to see the model's orchestration in action is to
give it several independent tools and let it run them in parallel.
This is where tools and
[concurrency](concurrency.md) meet: the model decides it needs
multiple answers, issues several tool calls, and the runtime
executes them concurrently before feeding every result back for
synthesis.

#### How it works

Attach independent tools to an agent and set a concurrency strategy
that matches the workload. For IO-bound tools like HTTP fetches,
`:async` or `:thread` give you parallelism without much overhead.
For process isolation or CPU-bound work, reach for `:fork` or
`:ractor`. The agent runs the tool loop, so it keeps calling,
collecting, and synthesizing until it has the answer. The model
reads the tool descriptions, decides which are independent, and
issues the calls. The runtime fans them out across the chosen
strategy, waits, and returns the combined results as context so the
model can synthesize a single answer:

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
tools = [FetchNews, FetchStocks, FetchFeeds]
agent = LLM::Agent.new(llm, tools:, concurrency: :fork)
agent.talk "Run the tools in parallel and summarize the results"
```

#### Why would I use it?

Parallel tool execution turns N round trips into one. A research,
monitoring, or automation agent that would otherwise call one tool,
wait, call the next, now gathers everything at once. The result
arrives faster and the model still gets the full picture before it
writes. The strategy is a single option, so you tune the trade-off
between speed (IO), isolation (fork), and CPU parallelism (ractor)
without touching your tool code.

#### Notes

The six strategies are documented in
[concurrency](concurrency.md). Whichever you choose, the tool
loop, confirmation, and error handling behave identically. A single
failing tool returns a structured error to the model, which can
decide to retry or continue with the results it has.

### Built-in tools

#### Overview

llm.rb ships with twelve ready-made tools that cover filesystem,
search, and shell operations. Load them all with
`require "llm/tools"`. Each tool is documented in the
[built-in tools catalog](builtin_tools.md).

#### How it works

When you want to attach the built-in tools to an agent, require
the catalog and pass the full set of subclasses as the `tools:`
option.

```ruby
require "llm"
require "llm/tools"

llm   = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tools: LLM::Tool.subclasses)
```

#### Why would I use it?

The built-in tools cover the operations a coding or system agent
needs most. See the
[built-in tools catalog](builtin_tools.md) for the full reference.

#### Notes

The tools that spawn subprocesses use the optional `test-cmd.rb`
gem for process management and interrupt handling.
