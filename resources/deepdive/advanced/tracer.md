
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
The built-in tracers include `LLM::Tracer::Logger` (writes to
stdout or a file) and `LLM::Tracer::Telemetry` (exports spans
via OTLP for OpenTelemetry).

#### Why would I use it?

Tracers give you visibility into what the runtime is doing. Debug
a misbehaving agent by tracing every request it makes. Monitor
request latency and token usage across providers. Export spans to
OpenTelemetry for integration with existing observability pipelines.

#### Notes

The tracer is extensible. You can implement custom hooks for any
runtime event. The scope can be an individual agent or every
request a provider makes.

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

The tracer can also write to a file: `LLM::Tracer::Logger.new(llm,
path: "deepseek.log")`.

### Agent

#### Overview

An agent-local tracer only covers requests made by that agent.
Attach it via `LLM::Agent.new(llm, tracer: ...)` and it follows
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

The tracer can also write to a file: `LLM::Tracer::Logger.new(llm,
path: "deepseek-agent.log")`.
