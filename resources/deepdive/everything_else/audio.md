
## Audio

### Introduction

#### Overview

The audio interface covers three things: turning text into speech,
transcribing audio into text, and translating spoken language.
OpenAI supports all three. Google and DeepInfra support subsets.
Each method follows the same pattern: pass input, get output,
copy the result somewhere useful.

#### How it works

When you want to convert text to speech, call
[`LLM::Audio#create_speech`](https://r.uby.dev/api-docs/llm.rb/LLM/Audio.html#create_speech).
The provider returns an audio clip as a `URIData` object. The generated audio can be copied
to a file or streamed directly. Each provider supports different
output formats and voice options:

```ruby
llm = LLM.openai(key: ENV["KEY"])
res = llm.audio.create_speech(input: "Hello world")
IO.copy_stream res.audio.decoded, "helloworld.mp3"
```

#### Why would I use it?

Audio support lets you build voice interfaces, add accessibility
features, and work across languages without wiring up a separate
speech service. Generate audio for notifications, narrate written
content, or add speech output to an existing application with a
single method call.

#### Notes

OpenAI has full audio support. Google and DeepInfra have partial
support. The `create_speech` method returns a `URIData` object.

### Transcription

#### Overview

Transcription turns an audio file into text. Pass a file path
to `create_transcription` and get back the spoken content as
a string. OpenAI, Google, and DeepInfra support it. Transcribe
meeting notes, voice memos, or podcast episodes for search and
processing. The response is plain text you can feed into any
downstream pipeline.

#### How it works

When you want to transcribe audio into text, call
[`LLM::Audio#create_transcription`](
  https://r.uby.dev/api-docs/llm.rb/LLM/Audio.html#create_transcription
).
The provider processes the audio and returns the
transcribed text. The file
can be a local path or a URL depending on provider support:

```ruby
llm = LLM.google(key: ENV["KEY"])
res = llm.audio.create_transcription(file: "helloworld.mp3")
res.text  # => "Hello world"
```

#### Why would I use it?

Transcribe recorded meetings, voice memos, or podcast episodes for
search and processing. The returned text feeds directly into search
indexes, summarization pipelines, or downstream extraction. Spoken
content becomes as queryable as written text.

#### Notes

OpenAI has full audio support. Google and DeepInfra have partial
support.


### Translation

#### Overview

Translation transcribes audio and translates it into English in
one step. Pass a file to `create_translation` and get back the
translated text. OpenAI and Google support it. Translate
multilingual podcasts, interviews, or any audio where you need
the content in English without running a separate translation
pipeline.

#### How it works

When you want to translate spoken audio into English, call
[`LLM::Audio#create_translation`](
  https://r.uby.dev/api-docs/llm.rb/LLM/Audio.html#create_translation
).
The provider transcribes the spoken language and translates the
result into English in a single operation. The returned text is the English translation:

```ruby
llm = LLM.google(key: ENV["KEY"])
res = llm.audio.create_translation(file: "bomdia.mp3")
res.text  # => "Good day"
```

#### Why would I use it?

Translate a podcast or interview into another language without a
separate speech service. The provider handles both transcription and
translation in a single call, so you get English text from any
supported source language without chaining two operations together.

#### Notes

Each method works independently and each provider supports a
different subset.
