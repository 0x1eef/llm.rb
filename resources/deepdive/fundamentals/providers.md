## Providers

### Introduction

#### Overview

llm.rb talks to 13+ providers through one API. OpenAI-compatible
providers (Anthropic, DeepSeek, DeepInfra, xAI, Z.ai, Moonshot,
Alibaba, Ollama, and llama.cpp) share the same OpenAI code path, so
switching models rarely means switching code. Each provider is
constructed with a class-level factory method on `LLM`, and the
result is passed to an `LLM::Context` or `LLM::Agent`.

#### How it works

Pick a provider by calling its factory method on `LLM`. Every
factory accepts the same `key:` option and returns a provider
instance you can hand to a context or agent:

```ruby
require "llm"

llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(llm)
ctx.talk "Hello"
```

The remaining providers are constructed the same way. OpenAI
compatible factories accept `host:` and `base_path:` so you can
point them at a compatible endpoint. `LLM.alibaba` is also aliased
as `LLM.aliyun`.

#### Why would I use it?

Providers are the first building block of every llm.rb program.
Because the whole runtime shares one provider interface, you can
swap one provider for another with a single line change, and the
same tools, schemas, streaming, and guards work unchanged.

#### Notes

Not every provider supports every endpoint. Image, audio, OCR,
embedding, and vector store support varies by provider and is
called out in the relevant topic. Providers that lack a given
endpoint raise `NotImplementedError`.

### Alibaba

#### Overview

[`LLM::Alibaba`](https://r.uby.dev/api-docs/llm.rb/LLM/Alibaba.html)
talks to [Alibaba Cloud Model Studio](https://www.alibabacloud.com/help/en/model-studio/models)
through its OpenAI-compatible API, including the Qwen3 family of
models. It is created with
[`LLM.alibaba`](https://r.uby.dev/api-docs/llm.rb/LLM.html#alibaba-class_method)
or its alias `LLM.aliyun`.

#### How it works

Create an Alibaba provider with an API key, then use it like any
other provider. The factory accepts the same `key:`, `host:`, and
`base_path:` options as the OpenAI provider, and defaults to the
`deepseek-v4-flash-0731` model. The default `host:` is the token
plan endpoint in Singapore,
`token-plan.ap-southeast-1.maas.aliyuncs.com`, with `base_path`
`/compatible-mode/v1`:

```ruby
require "llm"

llm = LLM.alibaba(key: ENV["ALIBABA_API_KEY"])
ctx = LLM::Context.new(llm)
ctx.talk "Hello"
```

`LLM.aliyun` is an alias for `LLM.alibaba`, so either name works.

The default host is my own token plan, so you will likely need to
point the provider at your own endpoint. Pass `host:` to use your
own token plan URL, or the pay-as-you-go host
(`dashscope-intl.aliyuncs.com` for the international region):

```ruby
# Your own token-plan endpoint
llm = LLM.alibaba(
  key: ENV["ALIBABA_API_KEY"],
  host: "token-plan.ap-southeast-1.maas.aliyuncs.com"
)

# Pay-as-you-go
llm = LLM.alibaba(
  key: ENV["ALIBABA_API_KEY"],
  host: "dashscope-intl.aliyuncs.com"
)
```

#### Why would I use it?

Alibaba Cloud Model Studio is a cost-effective option for API
users, and the Qwen3 family covers chat, streaming, and tool calls.
Because it is OpenAI-compatible, code written for OpenAI runs
unchanged; only the factory call changes.

#### Notes

Alibaba supports chat completions, streaming, tool calls, and
structured output through the shared OpenAI-compatible path.
Structured output uses a `json_object` fallback because Alibaba
models do not support `json_schema` natively. The image, audio,
moderation, responses, and vector store endpoints raise
`NotImplementedError`.

The default host points at a token plan in Singapore, which happens
to be my default. Your own token plan lives at a different URL, and
pay-as-you-go users should use the regional dashscope host instead.
Check your Model Studio dashboard for the correct endpoint.

Model metadata ships in `data/alibaba.json` for the registry.