
## Transports

### Introduction

#### Overview

The transport option selects which HTTP library is used for network
communication.
[`LLM::Provider`](https://r.uby.dev/api-docs/llm.rb/LLM/Provider.html),
[`LLM::MCP`](https://r.uby.dev/api-docs/llm.rb/LLM/MCP.html), and
[`LLM::A2A`](https://r.uby.dev/api-docs/llm.rb/LLM/A2A.html)
all accept this option. Three backends are available out of the box:
`net/http` is always there, `net/http/persistent` pools connections,
and `curb` wraps libcurl. Each implements the same internal interface
so switching between them is a one-word change.

#### How it works

**Net/HTTP** (`:net_http`) is the
default and is always available. **Net/HTTP/Persistent**
(`:net_http_persistent`) maintains a connection pool so the cost
of tearing down and setting up connections is kept low. **Curb**
(`:curb`) provides bindings for libcurl.

```ruby
llm = LLM.deepseek(key: "...", transport: :net_http)
mcp = LLM::MCP.http(url: "...", transport: :net_http_persistent)
a2a = LLM::A2A.rest(url: "...", transport: :curb)
```

#### Why would I use it?

Different environments have different HTTP needs.

The default `net/http` transport is always available and works
everywhere. The persistent transport reduces connection overhead
when your agent makes many requests to the same provider in quick
succession. Curb gives you libcurl bindings for environments where
that is already configured or preferred.

#### Notes

The persistent transport is built on top of `net/http`. Curb
requires the `curb` gem.
