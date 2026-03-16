## About

EasyTalk is a demo app for [llm.rb](https://github.com/llmrb/llm.rb) that shows
how to build a complex streaming chat interface with multiple providers and tools.
It is implemented as a Rack application with Falcon and async-websocket support, and
the frontend is built with React and webpack. It supports OpenAI, Gemini, Anthropic,
xAI and DeepSeek, and you can add your own tools by following the example of
[create_image.rb](./app/tools/create_image.rb). Enjoy :)

## Features

- ⚙️ Rack application built with Falcon and async-websocket
- 🌊 Streaming chat over WebSockets
- 🔀 Switch providers: OpenAI, Gemini, Anthropic, xAI and DeepSeek
- 🧠 Switch models: varies by provider
- 🛠️ Add your own tools: see [app/tools/](app/tools)
- 🖼️ Image generation via [create_image.rb](./app/tools/create_image.rb) - requires Gemini, OpenAI or xAI but works with any provider

## Screencast

<p align="center">
  <a href="https://www.youtube.com/watch?v=FsSn7KuWY8o">
    <img src="https://img.youtube.com/vi/FsSn7KuWY8o/maxresdefault.jpg" alt="Watch the EasyTalk demo on YouTube">
  </a>
</p>

## Usage

**Secrets**

Set your secrets in `.env`:

```sh
OPENAI_SECRET=...
GEMINI_SECRET=...
ANTHROPIC_SECRET=...
DEEPSEEK_SECRET=...
XAI_SECRET=...
```

**Packages**

Install Ruby gems:

```sh
bundle install
```

Build the frontend:

```sh
bundle exec rake build
```

**Serve**

Start the server:

```sh
set -a
. ./.env
set +a
bundle exec falcon serve --bind http://localhost:9292
```

## Sources

* [GitHub.com](https://github.com/llmrb/easytalk)
* [GitLab.com](https://gitlab.com/llmrb/easytalk)
* [Codeberg.org](https://codeberg.org/llmrb/easytalk)

## License

[BSD Zero Clause](https://choosealicense.com/licenses/0bsd/)
<br>
See [LICENSE](./LICENSE)
