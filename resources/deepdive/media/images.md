
## Images

### Introduction

#### Overview

A handful of providers can generate images from a text prompt.
OpenAI, Google, xAI, DeepInfra, and DeepSeek all support it.
OpenAI, xAI, and DeepInfra also let you edit existing images.
The API is the same across providers, so switching between them
requires no code changes.

#### How it works

The
[`LLM::Images#create`](https://r.uby.dev/api-docs/llm.rb/LLM/Images.html#create)
method sends a prompt to the provider and
returns the result as a
[`LLM::URIData`](https://r.uby.dev/api-docs/llm.rb/LLM/URIData.html)
object. The same API works
across providers: swap
[`LLM.openai`](https://r.uby.dev/api-docs/llm.rb/LLM.html#openai-class_method) for
[`LLM.xai`](https://r.uby.dev/api-docs/llm.rb/LLM.html#xai-class_method) and the rest
of the code is identical.

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.images.create(prompt: "a dog on a rocket to the moon")
IO.copy_stream res.images[0], "dogrocket.png"
```

#### Why would I use it?

Image generation and editing let the model produce visual output
directly from your prompts. The API is the same across providers,
so switching between OpenAI and xAI requires changing one line.
Prototype visual concepts, generate assets, or augment datasets
without wiring up a separate image API.

#### Notes

Google only supports image generation, not edits. DeepSeek
generates SVGs rather than raster images. DeepSeek can also
maintain a session across multiple generations through the
`agent` parameter on the response object.

### Editing

#### Overview

Image editing takes an existing image and a text prompt, then
produces a modified version. You can add objects, change colours,
or alter the scene while keeping the original composition.
OpenAI, xAI, and DeepInfra support raster image edits. DeepSeek
generates SVG documents which can be refined with follow-up
text-to-image prompts, giving you iterative vector editing.

#### How it works

The
[`LLM::Images#edit`](https://r.uby.dev/api-docs/llm.rb/LLM/Images.html#edit)
method takes a prompt and an image path. It
returns a modified image as a
[`LLM::URIData`](https://r.uby.dev/api-docs/llm.rb/LLM/URIData.html)
object. Copy the result
to a file the same way you would with generated images.

```ruby
llm = LLM.openai(key: ENV["KEY"])
res = llm.images.edit(prompt: "add a mustache", image: "self.jpg")
IO.copy_stream res.images[0], "mustache.png"
```

#### Why would I use it?

Editing lets the model modify existing images rather than starting
from scratch. DeepSeek's SVG output is particularly useful here
because vector graphics can be refined iteratively. Make targeted
adjustments: add objects, change colours, or alter the scene,
all while keeping the original composition intact.

#### Notes

Google does not support image edits. DeepSeek can maintain a
session across multiple generations through the `agent` parameter
on the response object.
