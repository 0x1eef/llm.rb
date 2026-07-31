
## Transformer

### Introduction

#### Overview

[`LLM::Transformer`](https://r.uby.dev/api-docs/llm.rb/LLM/Transformer.html)
is the superclass for message transformers. A transformer is bound
to a context and rewrites a single message before it is sent to the
provider. This lets you scrub sensitive data, inject context, or
otherwise modify outgoing messages without changing your prompt
code.

#### How it works

A transformer is a subclass of
[`LLM::Transformer`](https://r.uby.dev/api-docs/llm.rb/LLM/Transformer.html)
that implements
[`LLM::Transformer#call`](https://r.uby.dev/api-docs/llm.rb/LLM/Transformer.html#call-instance_method).
The method receives the message to transform and returns a message.
You can mutate the message in place or return a new one; either way,
the returned message is what gets sent.

Configure the transformer on a context with the `transformer:` option,
passing a class rather than an instance. The runtime instantiates it
once per turn. Options passed through `transformer_options:` are
forwarded to `call` as keyword arguments:

```ruby
class RedactEmails < LLM::Transformer
  def call(message:, **opts)
    content = message.content.to_s.gsub(/[\w.+-]+@[\w-]+\.[\w.]+/, "[EMAIL]")
    LLM::Message.new(message.role, content, message.extra)
  end
end

llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(
  llm,
  transformer: RedactEmails
)
ctx.talk "Contact support@example.com for help"
```

The transformer runs on the most recent message in both chat
completions and Responses API turns, before the request reaches the
provider.

#### Why would I use it?

Transformers give you a single hook point for all outgoing messages.
Common uses include redacting PII before it leaves your process,
injecting a timestamp or request ID, or normalizing content for a
particular provider. Because the transformer runs automatically on
every turn, you never need to remember to apply the transform in
your prompt code.

#### Notes

[`LLM::Transformer::Null`](https://r.uby.dev/api-docs/llm.rb/LLM/Transformer/Null.html)
is the default transformer; it returns the message unchanged. The
`transformer_options:` hash is passed to `call` on every turn.
Streams can observe transformation through the
[`LLM::Stream#on_transform`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_transform-instance_method)
and
[`LLM::Stream#on_transform_finish`](https://r.uby.dev/api-docs/llm.rb/LLM/Stream.html#on_transform_finish-instance_method)
callbacks, which receive the transformer instance.
