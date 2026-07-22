
## Schema

### Introduction

#### Overview

A schema describes the shape of a structured response you expect
from the model. Instead of parsing free-form text, you declare
the expected structure and the runtime coerces the response into
an object with typed accessors.

#### How it works

When you want a structured response from the model, subclass
[`LLM::Schema`](https://r.uby.dev/api-docs/llm.rb/LLM/Schema.html)
and declare properties with types and constraints. When you pass the schema to `talk`, the runtime
includes it in the request parameters. The provider returns a
JSON object matching the schema, which is coerced into an
[`LLM::Object`](https://r.uby.dev/api-docs/llm.rb/LLM/Object.html) with typed accessors.

```ruby
class Estimation < LLM::Schema
  property :age, Integer, "The estimated age of the person"
  property :confidence, Number, "Your confidence in the estimate"
  property :applicable, Boolean, "True when the photo contains a person"
  property :comments, String, "Any additional comments"
  required %i[age confidence applicable comments]
end

llm = LLM.openai(key: ENV["KEY"])
agent = LLM::Agent.new(llm, schema: Estimation)
res = agent.ask "Given this photo, provide an age estimate", with: "photo.jpg"

estimate = res.content!

if estimate.applicable
  print "The person is approx ", estimate.age.to_s, " years old"
else
  print "This photo is not applicable: ", estimate.comments
end
```

#### Why would I use it?

Schemas give you structured data instead of free text. Pass the
result to other code without parsing. Use them for classification,
extraction, or any workflow where the output needs to feed into
another system.

#### Notes

Schemas can define objects, arrays, enums, and nested schemas.
They are also used internally by
[`LLM::Tool`](https://r.uby.dev/api-docs/llm.rb/LLM/Tool.html)
for parameter definitions, so you already benefit from them
when you declare tool parameters.
