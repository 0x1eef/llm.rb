
## REPL

### Introduction

#### Overview

The REPL drops you into a curses-based TUI for talking to an agent
interactively. It has a scrollable transcript that renders markdown,
a multi-line input area, and a status bar showing context usage and
cost. The UI thread stays responsive while a second thread communicates
with the model. Think of it as `binding.pry` but for agents.

#### How it works

The REPL runs on two threads: one for the curses UI (input handling,
transcript rendering, status bar) and one for model communication.

The `name:` option labels the agent in the prompt. The `path:`
option persists state across sessions. The `tools:` option attaches
extra tools for the session.

Commands start with `/` and are dispatched to registered
[`LLM::Command`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Command.html)
subclasses. Type `/compact` to free context window
space, `/exit` to leave.

When characters arrive faster than a threshold, the REPL detects
paste mode. In paste mode, pressing Enter inserts a newline instead
of submitting.

Start a session with:

```ruby
require "llm"
require "llm/tools"

llm = LLM.deepseek(key: ENV["KEY"])
agent = LLM::Agent.new(llm, name: "my-agent", path: "session.json")
agent.repl(tools: LLM::Tool.subclasses)
```

#### Why would I use it?

The REPL gives you an interactive environment to test agents, debug
tool calls, and inspect conversation state without writing a
separate UI. Drop in after running an agent to confirm it did what
you expected. Inspect what went wrong when it did not. Keep talking
to the same agent while its state is still intact. It is
`binding.pry` but for agents.

#### Notes

The REPL requires the `curses` and `kramdown` gems. By default the
tracer is disabled during the session. Set `tracer: true` to keep
it active.

The user-message label is exposed through
[`LLM::Repl#sender`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl.html#sender-instance_method),
which defaults to `"You"`. The
[`LLM::Repl#write_message`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl.html#write_message-instance_method)
and
[`LLM::Repl::Buffer#write_message`](https://r.uby.dev/api-docs/llm.rb/LLM/Repl/Buffer.html#write_message-instance_method)
helpers write a formatted `user:` message with a trailing newline,
and `LLM::Command#write_message` matches the same interface.

Commands use the same vocabulary as tools: declare a name,
description, and parameters with `parameter` and `required`.
Subclassing an existing command inherits its name, description,
and parameters. This is how `/quit` is an alias of `/exit`.

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

The input area supports several keyboard shortcuts:

| Key | Action |
|---|---|
| `Ctrl+A` | Jump to the start of the line |
| `Ctrl+E` | Jump to the end of the line |
| `Ctrl+F` | Move cursor forward by one column |
| `Ctrl+K` | Erase from cursor to end of line |
| `Ctrl+P` / `Ctrl+N` | Recall previous / next user message |
| `Ctrl+Y` | Paste previously killed text |
| `Enter` | Submit the current prompt |
| `Tab` | Complete `/command` names |
| `Esc` | Cancel the current request |
| `Up` / `Down` | Scroll the transcript one line |
| `PgUp` / `PgDn` | Scroll the transcript by one page |
