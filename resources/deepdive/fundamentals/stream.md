
## Stream

### Introduction

#### Overview

Streaming delivers model output as it is generated, token by
token, instead of waiting for the full response. The user sees
text appear in real time, and the application can act on partial
results as they arrive.

#### How it works

The stream target can be any object that responds to `#<<`. Each
time the provider emits a token, the runtime calls `target <<
chunk` with the raw content. The tokens arrive in order as the
model generates them, so the output appears character by character
instead of all at once. When the response is complete, the stream
closes and control returns to the caller.

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, stream: $stdout)
agent.talk "hello world"
```

#### Why would I use it?

Streaming lets users see output sooner and cancel mid-response if
the model goes off course. It also lets you add progress indicators and
partial result processing, things that are not possible with a
single blocking response.

#### Notes

The IO-like form is equivalent to
[`LLM::Stream#on_content`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_content)
and does not include the other hooks. It covers content output
(piping to stdout or a log file) without the overhead of a full
subclass. A
[`LLM::Stream`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html)
subclass gives you visibility into tool calls, compaction events,
and reasoning content.

### Callbacks

#### Overview

A stream subclass provides structured hooks into content, tool
calls, compaction, and other runtime events. Each hook fires at
a specific point in the request lifecycle. This gives you
fine-grained visibility into what the runtime is doing as it
happens, from the first token to the final tool return.

#### How it works

When you want to react to specific runtime events, override the
hooks on a
[`LLM::Stream`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html)
subclass.
[`LLM::Stream#on_content`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_content)
receives tokens as they arrive.
[`LLM::Stream#on_tool_call`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_tool_call)
fires when the model requests a tool.
[`LLM::Stream#on_tool_return`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_tool_return)
fires when the tool completes. Compaction hooks
let you show progress or log what was trimmed.

```ruby
class MyStream < LLM::Stream
  def on_content(content)
    print content
  end

  def on_reasoning_content(content)
    warn content
  end

  def on_tool_call(tool)
  end

  def on_tool_return(tool, result)
  end

  def on_compaction(compactor)
  end

  def on_compaction_finish(compactor)
  end
end

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, stream: MyStream.new)
agent.talk "Explain Ruby fibers."
```

#### Why would I use it?

A stream subclass gives you visibility into more than just content chunks. React to tool
calls as they happen, show compaction progress, or integrate with
an existing observability stack.

#### Notes

The IO-like form is equivalent to
[`LLM::Stream#on_content`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_content)
and does not include the other hooks.
