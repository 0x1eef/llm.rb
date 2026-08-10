
## Context

### Introduction

#### Overview

[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
is the runtime that powers every agent. When you call
[`LLM::Agent#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#talk),
the agent delegates to its internal context. The context manages
the message history, sends requests to the provider, tracks pending
tool calls, and feeds results back to the model. Everything an agent
does, a context does too, but without the automatic tool loop.

Using a context directly gives you finer control over each step
of the conversation. You decide when to send messages, when to
execute tools, and when to stop. This is useful for custom
confirmation flows, mixed concurrency strategies per tool, or
any workflow where the agent's automatic loop gets in the way.

#### How it works

A context wraps a provider and maintains the conversation state.
Call
[`LLM::Context#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#talk)
to send input to the model, check
[`LLM::Context#pending_functions?`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#pending_functions?)
to see if tools were requested, and use
[`LLM::Context#wait`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#wait)
to execute them. Each call to
[`LLM::Context#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#talk)
appends
to the conversation and returns the model's response. The context
serializes its state with
[`LLM::Context#to_h`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#to_h)
and
[`LLM::Context#to_json`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#to_json),
and restores it
with
[`LLM::Context#restore`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#restore).
This is how the ORM integrations and filesystem
persistence work under the hood:

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(llm)

res = ctx.talk "What's the weather in Tokyo?"
puts res.content
```

#### Why would I use it?

A bare context gives you control that the agent
abstraction does not expose. Pre-flight checks on tool requests,
per-tool confirmation prompts, mixed concurrency strategies across
tools, or manual iteration until a condition is met are all easier
with a bare context.

#### Notes

The agent uses
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
internally. Anything you can do with
a context, you can also do through an agent. The trade-off is
convenience versus control. Contexts support the same concurrency
strategies, compaction, cancellation, and serialization as agents.

OpenAI contexts default to the Responses API (`mode: :responses`)
with `store: false`, so no conversation state is kept server-side.
Pass `mode: :completions` to use the legacy Chat Completions API
instead. Every other provider defaults to `mode: :completions`.

A raw context disables rate-limit retries by default (`retry_budget: 0`).
Pass `retry_budget:` to retry a rate-limited request up to that many
times. Each retry sleeps a growing interval (2s, 4s, 6s, ...) and
notifies the stream through
[`LLM::Stream#on_rate_limit`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_rate_limit-instance_method)
before trying again. An `LLM::Agent` enables a budget of 3 by
default, so most users never touch this directly.

### Manual loop

#### Overview

[`LLM::Agent`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html)
manages the tool loop automatically. It calls
the model, checks for tool requests, runs the tools, feeds results
back, and repeats until the model produces text. You can bypass
this and drive
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
directly instead. This
gives you finer control over each step of the loop at the cost of
more code.

#### How it works

When you want to control the tool loop yourself, drive
[`LLM::Context`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html)
directly instead of using an agent. Start a conversation, check
for tool requests, execute them, and feed results back. The full
loop is under your control. Each call to
[`LLM::Context#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#talk)
appends to the conversation and returns the model's response, and
[`LLM::Context#pending_functions?`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#pending_functions?)
tells you whether tools were requested.
From that foundation you can inspect, iterate, or confirm
per-tool in a single flow:

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(llm)

loop do
  res = ctx.talk("What's the weather in Tokyo?")
  break unless ctx.pending_functions?

  puts "Model requested #{ctx.pending_functions.size} tool(s)"

  results = ctx.pending_functions.map do |fn|
    print "Run #{fn.name} with #{fn.arguments}? [y/N] "
    if $stdin.gets&.match?(/\Ay\z/i)
      fn.task(:thread).wait
    else
      fn.cancel(reason: "user declined")
    end
  end

  ctx.talk(results)
end

puts res.content
```

#### Why would I use it?

Manual control gives you pre-execution checks, custom confirmation
flows, different strategies per tool, and fine-grained error
recovery that the default tool loop does not expose.

#### Notes

[`LLM::Context#wait`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#wait)
picks up pending functions, spawns them using the chosen
strategy, waits for results, and records them back in the context.
Each strategy is supported: `:sequential`, `:thread`, `:fiber`,
`:async`, `:fork`, and `:ractor`. Functions are reset after each
[`LLM::Context#wait`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#wait)
or
[`LLM::Context#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#talk)
call. Store the array if you need to
preserve them.

### Pending functions

#### Overview

Pending function calls represent the model's tool requests. After
[`LLM::Context#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#talk)
returns, the context may have pending function
calls if the model requested tools. These are available through
[`LLM::Context#pending_functions`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#pending_functions)
which returns an array of
[`LLM::Function`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html)
objects. Each function has a name, arguments, and methods for
execution or cancellation.

#### How it works

When you want to check whether the model requested tools, call
[`LLM::Context#pending_functions?`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#pending_functions?)
after each
[`LLM::Context#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#talk)
call. Each pending
function has a name, arguments, and
methods for execution or cancellation. Call
[`LLM::Function#task`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#task)
to execute it or
[`LLM::Function#cancel`](https://r.uby.dev/api-docs/llm.rb/LLM/Function.html#cancel)
to skip it. Iterate over all
pending functions to inspect or handle them individually:

```ruby
res = ctx.talk "What's the weather in Tokyo?"

if ctx.pending_functions?
  puts "Model requested #{ctx.pending_functions.size} tool(s)"
  results = ctx.pending_functions.map do |fn|
    print "Run #{fn.name} with #{fn.arguments}? [y/N] "
    if $stdin.gets&.match?(/\Ay\z/i)
      fn.task(:thread).wait
    else
      fn.cancel(reason: "user declined")
    end
  end
  ctx.talk(results)
end
```

#### Why would I use it?

Inspecting pending functions lets you decide which tools to run,
in what order, and with what strategy. This is essential for
confirmation flows, selective execution, or logging which tools
the model requested.

#### Notes

Pending functions are reset after each
[`LLM::Context#wait`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#wait)
or
[`LLM::Context#talk`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#talk)
call. If you need to preserve them, store the array before
executing. Functions that are cancelled still count as completed
from the model's perspective; the model sees a cancellation
result, not a tool error.

### Tool responses

#### Overview

A tool interrupt gives you two choices. When a tool receives
[`LLM::Interrupt`](https://r.uby.dev/api-docs/llm.rb/LLM/Interrupt.html),
it can either cancel the turn or return a result. The choice
depends on the situation.
A hard cancel aborts the request outright and is the default.
Returning a value lets the model adapt and continue the
conversation, which can be useful when the interrupt is
temporary, like a timeout or a user pause.

#### How it works

When a tool receives
[`LLM::Interrupt`](https://r.uby.dev/api-docs/llm.rb/LLM/Interrupt.html),
re-raise to abort the turn or return a value to continue the loop.
The model receives the result and decides what to do next.

Re-raise to abort the turn entirely:

```ruby
class MyTool < LLM::Tool
  def call
    # do work
  rescue LLM::Interrupt
    cleanup
    raise
  end
end
```

Return a value to continue the loop:

```ruby
class MyTool < LLM::Tool
  def call
    # do work
  rescue LLM::Interrupt
    cleanup
    {ok: false, reason: "interrupted"}
  end
end
```

#### Why would I use it?

A hard cancel aborts the request outright. Useful when continuing
would produce garbage. Returning a value lets the model adapt,
which can be helpful when the interrupt is temporary.

#### Notes

The mechanism is the same across all six concurrency strategies.
The `:ractor` strategy delivers the interrupt through ractor
message passing. The `:fork` strategy delivers it via xchan.

