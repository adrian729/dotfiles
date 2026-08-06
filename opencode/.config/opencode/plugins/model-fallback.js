// model-fallback — resend rate-limited sessions on a free fallback model
import { readFileSync } from "node:fs"
import { homedir } from "node:os"

const COOLDOWN_RATE_MS = 5 * 60 * 1000
const COOLDOWN_QUOTA_MS = 6 * 60 * 60 * 1000
const MIN_RESEND_INTERVAL_MS = 30 * 1000
const MAX_RESENDS_PER_SESSION = 4

// Quota errors persist for hours; rate-limit/5xx clear in minutes. The 30s
// resend interval and per-session cap stop our own resends from looping.
const QUOTA_RE = /quota|usage limit|credit limit|billing|plan limit|limit reached/i
const RATE_RE = /rate ?limit|too many requests|429|high concurrency|overloaded|temporarily unavailable|exceeded|busy/i

// Last-resort list if both config files are unreadable
const SEED = [
  "opencode/deepseek-v4-flash-free",
  "opencode/mimo-v2.5-free",
  "opencode/laguna-s-2.1-free",
  "opencode/ling-3.0-flash-free",
  "opencode/north-mini-code-free",
  "opencode/nemotron-3-ultra-free",
  "opencode/big-pickle",
]

const home = homedir()
const MODEL_CONFIG = `${home}/.local/config/opencode-models.json`
const PROBE_STATE = `${home}/.local/state/agents/opencode-agent-models.json`

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"))
  } catch {
    return null
  }
}

function buildFallbacks() {
  let preferred = SEED
  const cfg = readJson(MODEL_CONFIG)
  if (cfg && Array.isArray(cfg.free_models)) {
    // ollama-cloud rate-limits like the paid tier — keep it out of the fallback path
    const filtered = cfg.free_models.filter((m) => !m.startsWith("ollama-cloud/"))
    if (filtered.length) preferred = filtered
  }
  const state = readJson(PROBE_STATE)
  const available = state && Array.isArray(state.available) ? state.available : null
  if (!available) return preferred
  const hit = preferred.filter((m) => available.includes(m))
  return hit.length ? hit : preferred
}

const fallbacks = buildFallbacks()
const cooldownUntil = new Map()
const lastResendAt = new Map()
const resendCount = new Map()

function classifyText(text) {
  if (QUOTA_RE.test(text)) return "quota"
  if (RATE_RE.test(text)) return "rate"
  return null
}

function classifyError(error) {
  if (!error || !error.data) return null
  const data = error.data
  if (data.name === "MessageAbortedError" || data.name === "ProviderAuthError") return null
  const kind = classifyText(data.message || "")
  if (kind) return kind
  if (typeof data.statusCode === "number") {
    if (data.statusCode === 402) return "quota"
    if (data.statusCode === 429 || data.statusCode === 408 || data.statusCode >= 500) return "rate"
  }
  return null
}

function retryAfterMs(data) {
  const headers = data.responseHeaders || {}
  const secs = parseInt(headers["retry-after"] || headers["Retry-After"] || "", 10)
  if (!Number.isFinite(secs) || secs <= 0) return 0
  return Math.min(secs * 1000, COOLDOWN_QUOTA_MS)
}

function cooldownFor(kind, data) {
  const base = kind === "quota" ? COOLDOWN_QUOTA_MS : Math.max(COOLDOWN_RATE_MS, retryAfterMs(data))
  return Date.now() + base
}

async function recover(client, sessionID, kind, data) {
  if (!sessionID) return
  const now = Date.now()
  if (now - (lastResendAt.get(sessionID) || 0) < MIN_RESEND_INTERVAL_MS) return
  if ((resendCount.get(sessionID) || 0) >= MAX_RESENDS_PER_SESSION) return

  let messages
  try {
    messages = await client.session.messages({ path: { id: sessionID } })
  } catch {
    return
  }
  messages = messages && typeof messages === "object" && "data" in messages ? messages.data : messages
  if (!Array.isArray(messages) || !messages.length) return

  const lastUser = [...messages].reverse().find((m) => m.info && m.info.role === "user")
  if (!lastUser) return

  const failed = lastUser.info.model
  if (failed && failed.modelID) {
    cooldownUntil.set(`${failed.providerID}/${failed.modelID}`, cooldownFor(kind, data || {}))
  }

  const text = (lastUser.parts || [])
    .filter((p) => p.type === "text")
    .map((p) => p.text)
    .join("\n\n")
  if (!text) return

  const target = fallbacks.find((m) => !cooldownUntil.has(m) || cooldownUntil.get(m) <= now)
  if (!target) return

  const [providerID, modelID] = target.split("/")
  lastResendAt.set(sessionID, now)
  resendCount.set(sessionID, (resendCount.get(sessionID) || 0) + 1)

  try {
    await client.session.abort({ path: { id: sessionID } })
  } catch {
    // session may have finished between the error and this abort
  }

  try {
    await client.app.log({
      body: {
        service: "model-fallback",
        level: "warn",
        message: `session ${sessionID} ${kind}-limited on ${failed ? `${failed.providerID}/${failed.modelID}` : "?"} — resending on ${target}`,
      },
    })
  } catch {}

  try {
    await client.tui.showToast({
      body: { message: `Model limit — retrying on ${target}`, variant: "warning" },
    })
  } catch {
    // headless runs have no TUI to toast
  }

  void client.session
    .prompt({
      path: { id: sessionID },
      body: { model: { providerID, modelID }, parts: [{ type: "text", text }] },
    })
    .catch(() => {})
}

export const ModelFallbackPlugin = async ({ client }) => {
  try {
    await client.app.log({
      body: {
        service: "model-fallback",
        level: "info",
        message: `loaded — fallbacks: ${fallbacks.join(", ")}`,
      },
    })
  } catch {}

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle" && event.properties && event.properties.sessionID) {
        resendCount.delete(event.properties.sessionID)
        lastResendAt.delete(event.properties.sessionID)
        return
      }
      if (event.type === "session.status" && event.properties && event.properties.status) {
        const { sessionID, status } = event.properties
        if (status.type !== "retry") return
        // quota won't clear in seconds — fall back immediately; for transient
        // rate limits give opencode's first internal retry a chance
        const kind = classifyText(status.message)
        if (kind === "quota" || (kind === "rate" && status.attempt >= 2)) {
          await recover(client, sessionID, kind, {})
        }
        return
      }
      if (event.type === "session.error" && event.properties) {
        const kind = classifyError(event.properties.error)
        if (kind) await recover(client, event.properties.sessionID, kind, event.properties.error.data)
      }
    },
  }
}
