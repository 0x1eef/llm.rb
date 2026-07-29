
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
runtime serialises the arguments and passes them to
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call).

If
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call)
raises, the runtime rescues it and returns a structured
error to the model instead. The conversation stays valid. You can
also handle errors yourself inside
[`LLM::Tool#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html#call)
by rescuing and returning a domain-specific error hash.

```ruby
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

#### Why would I use it?

Tools are how the model interacts with the outside world. Without
them, the model can only produce text. With tools, it can query
databases, run shell commands, fetch web pages, or call APIs. The
tool loop stays alive even when a tool fails. One broken tool does
not derail the conversation.

#### Notes

Confirmation gates tools behind explicit approval. List tool names
in
[`LLM::Agent#confirm`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#confirm)
to block execution until you override
[`LLM::Agent#on_tool_confirmation`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#on_tool_confirmation).
Confirmation also accepts a Symbol for
lazy resolution. A Symbol lets the confirmed set change
per-instance based on runtime conditions.

For dynamic confirmation lists, pass a Symbol that resolves to an
instance method:

```ruby
class AdaptiveAgent < LLM::Agent
  set confirm: :tools_that_need_confirmation

  def tools_that_need_confirmation
    some_condition ? %w[delete destroy] : %w[delete]
  end
end
```

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
