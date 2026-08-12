
## LLM::Cost

### Introduction

#### Overview

[`LLM::Cost`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html)
represents the approximate cost of a conversation. It breaks the
total down by token type, so you can see how much was spent on input,
output, cached tokens, reasoning, audio, and images. Cost is computed
from token usage and the pricing data shipped in the model registry.

#### How it works

When you want to know what a conversation cost so far, call
[`LLM::Context#cost`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#cost-instance_method)
(or
[`LLM::Agent#cost`](https://r.uby.dev/api-docs/llm.rb/LLM/Agent.html#cost-instance_method))
and read the breakdown. The REPL shows this live in its status bar
after every turn:

```ruby
llm = LLM.deepseek(key: ENV["KEY"])
ctx = LLM::Context.new(llm)
ctx.talk "Hello"

cost = ctx.cost
cost.input    # => 0.0000042
cost.output   # => 0.0000084
cost.total    # => 0.0000126
cost.to_s     # => "0.00"
```

#### Why would I use it?

Cost tracking matters in production. Monitoring spend per
conversation, per agent, or per provider tells you which workflows
are expensive and when to switch models. Log a structured breakdown
with
[`LLM::Cost#to_h`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#to_h-instance_method),
or read
[`LLM::Cost#total`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#total-instance_method)
for a single number.

#### Notes

Cost is an approximation based on the pricing in the model registry.
[`LLM::Cost.from`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#from-class_method)
returns an empty cost when the model or registry cannot be found, so
a missing model never crashes your code.

### Reading the breakdown

#### Overview

[`LLM::Cost`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html)
exposes each cost component as a reader, plus
[`LLM::Cost#total`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#total-instance_method),
[`LLM::Cost#to_h`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#to_h-instance_method),
and
[`LLM::Cost#to_s`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#to_s-instance_method).

#### How it works

Each component is a Float, and defaults to `0` when no tokens of
that type were used. The
[`LLM::Cost#to_h`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#to_h-instance_method)
method returns a Hash with every component and the total:

```ruby
cost = ctx.cost

cost.input
cost.output
cost.cache_read
cost.cache_write
cost.reasoning
cost.input_audio
cost.output_audio
cost.input_image

cost.to_h  # => {input: 4.2e-06, output: 8.4e-06, cache_read: 0.0,
           #     cache_write: 0.0, input_audio: 0.0, output_audio: 0.0,
           #     input_image: 0.0, reasoning: 0.0, total: 1.26e-05}
```

#### Why would I use it?

The per-component breakdown shows where the money goes. High cache
read costs suggest a conversation benefits from prompt caching.
High reasoning costs point at a model that thinks a lot. Log
[`LLM::Cost#to_h`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#to_h-instance_method)
at the end of a session to keep a spend trail.

#### Notes

[`LLM::Cost#to_s`](https://r.uby.dev/api-docs/llm.rb/LLM/Cost.html#to_s-instance_method)
returns the total in a compact, human-friendly format, rounded to
two decimals (`"0.01"`). Components that were not used are `0`, so
you never need to guard against `nil` when aggregating.

The REPL renders context usage as a proportion, not a cost.
[`LLM::Context#context_usage`](https://r.uby.dev/api-docs/llm.rb/LLM/Context.html#context_usage-instance_method)
returns a `Rational` of the tokens used over the context window
(for example `Rational(100, 10_000)`), or `nil` when the window is
unknown or the conversation is too short.
