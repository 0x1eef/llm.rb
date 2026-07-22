
## Concurrency

### Introduction

#### Overview

llm.rb supports six concurrency strategies for tool execution:
`:sequential`, `:thread`, `:fiber`, `:async`, `:fork`, and
`:ractor`. Each implements the same interface (`spawn`, `wait`,
`alive?`, `interrupt!`), so the caller never has to care which
strategy is behind a given task.

#### How it works

Each strategy creates a task object that wraps a function call.
`spawn` starts execution, `wait` collects the result, `alive?`
checks whether the task is still running, and `interrupt!` signals
the task to stop.

Interruption is reliable across all six.
[`LLM::Interrupt`](https://r.uby.dev/api-docs/llm.rb/LLM/Interrupt.html)
reaches the tool regardless of whether it runs on a thread, fiber, process,
or ractor. The tool can rescue, clean up, and either re-raise to
cancel the turn or return a value to continue.

```ruby
agent = LLM::Agent.new(llm, concurrency: :fork, tools: [...])

fn = FetchStocks.function
fn.task(:thread).wait
```

#### Why would I use it?

Different tools have different execution requirements. IO-bound
tools benefit from thread or async concurrency. CPU-bound tools
benefit from ractors or forks. Tools that might crash the process
should run in a fork for isolation.

The common interface means you can change strategies without
changing your tool code.

#### Notes

**sequential**: Tools run one at a time on the calling thread. No
overhead. Best for simple agents or when tool order matters.

**thread**: Each tool runs in its own Thread. Releases the GVL
during blocking IO. Best for IO-bound tools like HTTP calls and
database queries.

**fiber**: Each tool runs in a scheduler-backed Fiber. Requires
`Fiber.scheduler`. Best for IO-bound tools inside an async
framework. Much lighter than threads.

**async**: Each tool runs as an `Async::Task` inside a managed
background reactor. Best for IO-bound tools when you want Async's
structured concurrency model without running your whole application
inside a reactor. Requires the `async` gem.

**fork**: Each tool runs in a forked child process. True parallelism
and process isolation. Best for shell commands, native extensions,
or anything you do not want touching the parent's memory. Requires
the `xchan` gem.

**ractor**: Each class-based tool runs in a Ruby Ractor. True
parallelism without the overhead of forking full processes. Only
class-based tools are supported. Arguments must be ractor-shareable.

| Strategy | Backing | Parallel? | Isolation? | Requires |
|---|---|---|---|---|
| `:sequential` | direct call | No | No | None |
| `:thread` | `Thread` | IO only (GVL) | No | None |
| `:fiber` | `Fiber.schedule` | Cooperative | No | `Fiber.scheduler` |
| `:async` | `Async::Reactor` | Cooperative | No | `async` gem |
| `:fork` | `Kernel.fork` | Yes (process) | Yes (memory) | `xchan` gem |
| `:ractor` | `Ractor` | Yes (CPU) | Limited | None |
