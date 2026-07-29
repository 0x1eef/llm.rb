
## Tracer

### Introduction

#### Overview

Tracers let you observe what the runtime is doing. They hook into
requests, tool calls, compactions, and other events. Debug a
misbehaving agent, monitor request latency, or export spans to
an observability backend. A provider-wide tracer intercepts every
request through that provider. An agent-local tracer only covers
requests made by that agent.

#### How it works

When you want to observe runtime events, subclass
[`LLM::Tracer`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer.html)
and implement the hooks you need.
The built-in tracers include [`LLM::Tracer::Logger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Logger.html) (writes
structured JSON to stdout or a file), [`LLM::Tracer::PrettyLogger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/PrettyLogger.html)
(writes human-readable single-line logs to stderr), and
[`LLM::Tracer::Telemetry`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Telemetry.html) (exports spans via OTLP for
OpenTelemetry).

#### Why would I use it?

Tracers give you visibility into what the runtime is doing. Debug
a misbehaving agent by tracing every request it makes. Monitor
request latency and token usage across providers. Export spans to
OpenTelemetry for integration with existing observability pipelines.
Use [`LLM::Tracer::PrettyLogger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/PrettyLogger.html) during development for compact,
human-readable output, [`LLM::Tracer::Logger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Logger.html) for structured JSON,
and [`LLM::Tracer::Telemetry`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Telemetry.html) for production observability.

#### Notes

The tracer is extensible. You can implement custom hooks for any
runtime event. The scope can be an individual agent or every
request a provider makes. Three built-in tracers are available:
[`PrettyLogger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/PrettyLogger.html) (human-readable), [`Logger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Logger.html) (structured JSON), and
[`Telemetry`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Telemetry.html) (OpenTelemetry).

### Provider

#### Overview

A provider-wide tracer intercepts every request made through that
provider. All agents sharing the same provider share the same
tracer. Use this to trace at the infrastructure level without
configuring each agent individually.

#### How it works

When you want every request through a provider to be traced, set
the tracer on the provider directly. Every request made through
that provider, regardless of which agent initiates it, flows
through the same tracer hooks. The provider holds a reference to the
tracer and passes it to every new context it creates. This ensures
consistent observability without configuring each agent individually.

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
llm.tracer = LLM::Tracer::Logger.new(llm, io: $stdout)
```

#### Why would I use it?

A provider-wide tracer captures every request at the infrastructure level.
All agents sharing the same provider share the same tracer.

#### Notes

The tracer can also write to a file:
[`LLM::Tracer::Logger.new(llm, path: "deepseek.log")`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Logger.html#initialize-instance_method).

### Agent

#### Overview

An agent-local tracer only covers requests made by that agent.
Attach it via [`LLM::Agent.new(llm, tracer: ...)`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#initialize-instance_method) and it follows
that agent wherever it goes. Different agents can have different
tracers.

#### How it works

When you want a tracer for a specific agent, pass it to the agent
on creation. Only requests made by
that agent flow through the tracer, leaving other agents on the
same provider unaffected.

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tracer: LLM::Tracer::Logger.new(llm, io: $stdout))
```

#### Why would I use it?

Agent-local tracers let each agent log differently.
One agent might log to stdout, another to a file, a third to
OpenTelemetry.

#### Notes

The tracer can also write to a file:
[`LLM::Tracer::Logger.new(llm, path: "deepseek-agent.log")`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Logger.html#initialize-instance_method).

### PrettyLogger

#### Overview

[`LLM::Tracer::PrettyLogger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/PrettyLogger.html)
writes human-readable single-line logs to stderr. Unlike
[`LLM::Tracer::Logger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Logger.html) (which emits structured JSON), the pretty
logger is designed for interactive development sessions where you
want to see request and tool-call activity at a glance.

#### How it works

Each request and tool call produces a single line on stderr with
the model, duration, and a summary of the activity. The logger
accepts an `io:` option to redirect output.

##### Provider-wide

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
llm.tracer = LLM::Tracer::PrettyLogger.new(llm)
```

##### Agent-local

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, tracer: LLM::Tracer::PrettyLogger.new(llm))
```

##### Custom output

```ruby
tracer = LLM::Tracer::PrettyLogger.new(llm, io: $stdout)
tracer = LLM::Tracer::PrettyLogger.new(llm, io: File.open("trace.log", "a"))
```

#### Why would I use it?

The pretty logger is the best choice for development. The output is
compact enough to follow in real time while still showing the model
name, duration, and tool calls. Switch to [`LLM::Tracer::Logger`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Logger.html) when
you need structured JSON for programmatic analysis, or to
[`LLM::Tracer::Telemetry`](https://r.uby.dev/api-docs/llm.rb/LLM/Tracer/Telemetry.html) when you need OpenTelemetry exports.

#### Notes

The pretty logger writes to `$stderr` by default. Set `io:` to
redirect output. All three built-in tracers share the same interface,
so switching between them requires changing only the class name.
