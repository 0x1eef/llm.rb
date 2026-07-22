
## Compaction

### Introduction

#### Overview

Long-running conversations consume tokens. Without intervention,
every turn pushes toward the model's context window limit. Compaction
drops old messages to keep the conversation alive. The runtime runs
a compactor automatically before each `talk` call, trimming the
oldest messages when the conversation exceeds a configured size.
This keeps the context window healthy without manual intervention.

#### How it works

Compactors run automatically before each `talk` call.
[`LLM::Compactor::Truncate`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Truncate.html)
strategy drops the oldest messages, keeping only the N most recent.
It preserves tool call/return pairs so the conversation never
contains an orphaned result.

The `keep:` parameter accepts an integer count or a percentage
string like `"80%"`. The default compactor is
[`LLM::Compactor::Null`](https://r.uby.dev/api-docs/llm.rb/LLM/Compactor/Null.html),
which does nothing. A compactor can also be used standalone.
The REPL provides a `/compact` command that accepts a count
or percentage.

```ruby
ctx = LLM::Context.new(
  llm,
  compactor: LLM::Compactor::Truncate,
  compactor_options: {keep: 64}
)

agent = LLM::Agent.new(
  llm,
  compactor: LLM::Compactor::Truncate,
  compactor_options: {keep: 128}
)

compactor = LLM::Compactor::Truncate.new(agent)
compactor.call(keep: 200)

# /compact        # keep last 128 messages
# /compact 50     # keep last 50 messages
# /compact 75%    # keep approximately 75% of messages
```

#### Why would I use it?

Without compaction, the provider eventually rejects requests because
the context window is full. Compaction keeps the conversation alive
by discarding old messages before they cause a problem.

Long-running agents that span hundreds of turns need this. A bug
investigation that bounces back and forth between diagnosis and
fix cannot fit every exchange in memory. Compaction trims the
unimportant parts and keeps the conversation alive.

#### Notes

The Truncate strategy is fast and has no dependencies. It operates
entirely in memory with a single pass over the message list. The
trade-off is that dropped messages are gone, so information may be
lost. Set `keep` to a higher number to retain more context.

Both strategies emit `on_compaction` and `on_compaction_finish`
stream callbacks so the UI can show progress. The context's
`compacted?` flag is `true` between compaction and the next model
response.
