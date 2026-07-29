
## A2A

### Introduction

#### Overview

The Agent-to-Agent (A2A) protocol lets agents communicate directly
over a network. Unlike MCP, which connects an agent to external
tools, A2A connects agents to other agents. A remote agent advertises
its skills through a card. The calling agent loads those skills as
local tools and calls them the same way it calls any other tool.
One agent can research, another can code, a third can review.

#### How it works

The REST transport communicates over standard HTTP and JSON. Both
transports expose the remote agent's skills as local
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html)
subclasses.

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
a2a   = LLM::A2A.rest(url: "https://agent.example.com")
agent = LLM::Agent.new(llm, tools: a2a.skills)
agent.talk "What's happening, fellow agent?"
```

#### Why would I use it?

A2A lets you compose autonomous agents that delegate and collaborate.
One agent researches a topic. Another writes code. A third reviews
the result. Each agent runs independently and communicates over
the network.

#### Notes

An agent's capabilities are advertised through a card. The
[`LLM::A2A::Card#interfaces`](https://r.uby.dev/api-docs/llm.rb/LLM/A2A/Card.html#interfaces)
method lists which transports a remote agent supports.

### JSON-RPC

#### Overview

JSON-RPC is an alternative transport for A2A agents. It uses a
more structured protocol than REST, with request and response
objects that follow the JSON-RPC 2.0 spec. Some agents advertise
only JSON-RPC, others advertise both. The
[`LLM::A2A::Card#interfaces`](https://r.uby.dev/api-docs/llm.rb/LLM/A2A/Card.html#interfaces)
method lists which transports a remote agent supports.

#### How it works

When you want to connect to a remote A2A agent using JSON-RPC,
provide a URL and optional headers. The agent's skill list is
fetched and translated into
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html) subclasses the model can call.

```ruby
require "llm"

llm   = LLM.deepseek(key: ENV["KEY"])
a2a   = LLM::A2A.jsonrpc(url: "https://agent.example.com")
agent = LLM::Agent.new(llm, tools: a2a.skills)
agent.talk "What's happening, fellow agent?"
```

#### Why would I use it?

JSON-RPC provides typed request and response objects that follow
the 2.0 spec, offering a more structured protocol than REST. Some
agents advertise only JSON-RPC, while others advertise both. The
[`LLM::A2A::Card#interfaces`](https://r.uby.dev/api-docs/llm.rb/LLM/A2A/Card.html#interfaces)
method lists which transports a remote agent supports.

#### Notes

JSON-RPC request and response objects are typed and follow the 2.0
spec. The
[`LLM::A2A.jsonrpc`](https://r.uby.dev/api-docs/llm.rb/LLM/A2A.html#jsonrpc-class_method)
transport provides structured message envelopes rather than plain
HTTP.

