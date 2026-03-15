import React, {useEffect, useLayoutEffect, useRef, useState} from "react"
import {marked} from "marked"

const protocol = window.location.protocol === "https:" ? "wss:" : "ws:"

export default function App() {
  const [status, setStatus] = useState("connecting")
  const [message, setMessage] = useState("")
  const [entries, setEntries] = useState([])
  const [provider, setProvider] = useState("openai")
  const [models, setModels] = useState([])
  const [model, setModel] = useState("")
  const [modelsLoading, setModelsLoading] = useState(false)
  const socketRef = useRef(null)
  const streamRef = useRef(null)

  const say = (text) => {
    setEntries((prev) => [...prev, {kind: "system", text}])
  }

  const tell = (text) => {
    setEntries((prev) => [...prev, {kind: "user", text}])
  }

  const scrollToBottom = () => {
    const stream = streamRef.current
    if (stream) {
      stream.scrollTop = stream.scrollHeight
    }
  }

  useEffect(() => {
    const controller = new AbortController()
    setModels([])
    setModel("")
    setModelsLoading(true)
    setStatus("loading models")
    fetch(`/models?provider=${encodeURIComponent(provider)}`, {signal: controller.signal})
      .then((response) => response.json())
      .then((payload) => {
        setModels(payload)
        setModel(payload[0]?.id || "")
        setModelsLoading(false)
        setStatus("ready")
      })
      .catch((error) => {
        if (error.name === "AbortError") {
          return
        }
        setModelsLoading(false)
        setStatus("model error")
        say("client: failed to load models")
      })

    return () => controller.abort()
  }, [provider])

  useEffect(() => {
    if (!model) {
      return
    }
    const socket = new WebSocket(
      `${protocol}//${window.location.host}/ws?provider=${encodeURIComponent(provider)}&model=${encodeURIComponent(model)}`
    )
    socketRef.current = socket
    setStatus("connecting")

    const stream = (chunk) => {
      setEntries((prev) => {
        const last = prev[prev.length - 1]
        if (last && last.kind === "assistant") {
          return [
            ...prev.slice(0, -1),
            {kind: "assistant", markdown: last.markdown + chunk}
          ]
        }
        return [...prev, {kind: "assistant", markdown: chunk}]
      })
    }

    socket.addEventListener("open", () => {
      setStatus("ready")
    })

    socket.addEventListener("close", () => {
      setStatus("closed")
    })

    socket.addEventListener("error", () => {
      setStatus("error")
      say("client: socket error")
    })

    socket.addEventListener("message", (event) => {
      try {
        const payload = JSON.parse(event.data)
        switch (payload.event) {
          case "welcome":
            say(`server: connected (${payload.provider || provider}${payload.model ? ` / ${payload.model}` : ""})`)
            break
          case "status":
            setStatus(payload.message)
            break
          case "delta":
            stream(payload.message)
            break
          case "done":
            setStatus("ready")
            break
          case "error":
            setStatus("error")
            say("server: server error")
            break
          default:
            break
        }
      } catch {
        say("client: recv failed")
      }
    })

    return () => socket.close()
  }, [provider, model])

  useLayoutEffect(() => {
    scrollToBottom()
  }, [entries])

  useEffect(() => {
    const stream = streamRef.current
    if (!stream) {
      return
    }

    const onLoad = (event) => {
      if (event.target instanceof HTMLImageElement) {
        scrollToBottom()
      }
    }

    stream.addEventListener("load", onLoad, true)
    return () => stream.removeEventListener("load", onLoad, true)
  }, [])

  const onSubmit = (event) => {
    event.preventDefault()
    const socket = socketRef.current
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      say("client: socket is not open")
      return
    }
    if (!message) {
      return
    }
    setStatus("waiting")
    tell(message)
    socket.send(message)
    setMessage("")
  }

  const onProviderChange = (event) => {
    setModels([])
    setModel("")
    setProvider(event.target.value)
  }

  return (
    <main className="h-screen bg-white font-sans text-zinc-900">
      <div className="mx-auto flex h-full min-h-0 w-full max-w-4xl flex-col gap-4 px-4 py-6 sm:px-6">
        <header className="border-b border-zinc-100 pb-3 text-center">
          <p className="text-sm font-medium tracking-[0.18em] text-zinc-400 uppercase">
            easytalk
          </p>
        </header>
        <div
          id="stream"
          ref={streamRef}
          className="min-h-0 flex-1 overflow-y-auto rounded-3xl border border-zinc-200 bg-zinc-50 p-4 text-[15px] leading-7 shadow-sm"
        >
          {entries.map((entry, index) => {
            if (entry.kind === "assistant") {
              return (
                <div key={index} className="mt-3 flex first:mt-0">
                  <div
                    className="max-w-[85%] rounded-3xl rounded-bl-lg bg-white px-4 py-3 text-zinc-900 shadow-sm ring-1 ring-zinc-200"
                    dangerouslySetInnerHTML={{
                      __html: `<div class="assistant-content max-w-none whitespace-normal [&_p]:my-0 [&_pre]:overflow-x-auto [&_pre]:rounded-2xl [&_pre]:bg-zinc-100 [&_pre]:p-3 [&_code]:font-mono [&_blockquote]:border-l-4 [&_blockquote]:border-zinc-300 [&_blockquote]:pl-4 [&_blockquote]:text-zinc-600 [&_img]:mt-2 [&_img]:h-auto [&_img]:max-h-[32rem] [&_img]:w-full [&_img]:max-w-2xl [&_img]:rounded-2xl [&_img]:object-contain">${marked.parse(entry.markdown)}</div>`
                    }}
                  />
                </div>
              )
            }

            if (entry.kind === "user") {
              return (
                <div key={index} className="mt-3 flex justify-end first:mt-0">
                  <div className="max-w-[75%] rounded-3xl rounded-br-lg bg-zinc-900 px-4 py-3 text-white shadow-sm">
                    {entry.text}
                  </div>
                </div>
              )
            }

            return (
              <div key={index} className="mt-3 text-center text-xs text-zinc-500 first:mt-0">
                {entry.text}
              </div>
            )
          })}
        </div>
        <p className="text-center text-sm text-zinc-500">
          Status: <span className="font-semibold text-zinc-700">{status}</span>
        </p>
        <div className="flex justify-center text-sm">
          <div className="flex items-center gap-3 text-zinc-500">
            <label className="flex items-center gap-2">
              <span>Provider</span>
              <select
                className="rounded-xl border border-zinc-200 bg-white px-3 py-2 text-zinc-900 outline-none focus:border-zinc-300 focus:ring-4 focus:ring-zinc-900/10"
                value={provider}
                onChange={onProviderChange}
              >
                <option value="openai">OpenAI</option>
                <option value="gemini">Gemini</option>
                <option value="anthropic">Anthropic</option>
                <option value="deepseek">DeepSeek</option>
              </select>
            </label>
            <label className="flex items-center gap-2">
              <span>Model</span>
              <select
                className="min-w-72 rounded-xl border border-zinc-200 bg-white px-3 py-2 text-zinc-900 outline-none focus:border-zinc-300 focus:ring-4 focus:ring-zinc-900/10 disabled:bg-zinc-100 disabled:text-zinc-400"
                value={model}
                disabled={modelsLoading || models.length === 0}
                onChange={(event) => setModel(event.target.value)}
              >
                {modelsLoading ? (
                  <option value="">Loading models...</option>
                ) : (
                  models.map((entry) => (
                    <option key={entry.id} value={entry.id}>
                      {entry.name || entry.id}
                    </option>
                  ))
                )}
              </select>
            </label>
            <span className="text-xs text-zinc-400">
              {modelsLoading ? "..." : `${models.length} models`}
            </span>
          </div>
        </div>
        <form
          className="sticky bottom-0 flex flex-col gap-2 bg-gradient-to-b from-white/0 via-white/90 to-white pt-3 pb-1"
          onSubmit={onSubmit}
        >
          <input
            className="h-13 w-full rounded-2xl border border-zinc-200 bg-white px-4 text-[15px] text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-300 focus:ring-4 focus:ring-zinc-900/10"
            type="text"
            placeholder="Type a message"
            autoComplete="off"
            value={message}
            onChange={(event) => setMessage(event.target.value)}
          />
          <div className="flex justify-end">
            <button
              className="min-w-24 rounded-full bg-zinc-900 px-4 py-3 text-sm font-semibold text-white transition hover:bg-zinc-800 focus:ring-4 focus:ring-zinc-900/10 focus:outline-none"
              type="submit"
            >
              Send
            </button>
          </div>
        </form>
      </div>
    </main>
  )
}
