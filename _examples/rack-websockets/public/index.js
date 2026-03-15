const protocol = window.location.protocol === "https:" ? "wss:" : "ws:"
const socket = new WebSocket(`${protocol}//${window.location.host}/ws`)

function getActiveReply(stream) {
  const div = stream.lastElementChild
  return div && div.dataset.role === "assistant" ? div : null
}

function say(message) {
  const stream = document.getElementById("stream")
  const div = document.createElement("div")
  div.textContent = message
  stream.appendChild(div)
  stream.scrollTop = stream.scrollHeight
}

function stream(message) {
  const stream = document.getElementById("stream")
  let div = getActiveReply(stream)
  if (!div) {
    div = document.createElement("div")
    div.dataset.role = "assistant"
    div.textContent = "assistant: "
    stream.appendChild(div)
  }
  div.textContent += message
  stream.scrollTop = stream.scrollHeight
}

;(function() {
  const recv = (event) => {
    const payload = JSON.parse(event.data)
    switch (payload.event) {
      case "welcome":
        say("server: connected")
        break
      case "delta":
        stream(payload.message)
        break
      case "done":
        say("server: stream complete")
        break
      case "error":
        say("server: server error")
        break
      default:
        break
    }
  }

  socket.addEventListener("open", () => {
    const status = document.getElementById("status")
    status.textContent = "open"
  })

  socket.addEventListener("close", () => {
    const status = document.getElementById("status")
    status.textContent = "closed"
  })

  socket.addEventListener("error", () => {
    const status = document.getElementById("status")
    status.textContent = "error"
  })

  socket.addEventListener("message", (event) => {
    try {
      recv(event)
    } catch {
      say("client: recv failed")
    }
  })
})();

;(function() {
  const form = document.querySelector("form")
  const input = document.querySelector('input[type="text"]')
  form.addEventListener("submit", (event) => {
    event.preventDefault()
    const message = input.value
    if (socket.readyState !== WebSocket.OPEN)
      return say("client: socket is not open")
    if (!message)
      return
    input.value = ""
    socket.send(message)
    say(`sent: ${message}`)
  })
})();
