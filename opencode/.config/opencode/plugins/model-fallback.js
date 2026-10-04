// Continue rate-limited interactive turns on an explicitly configured free model.
import { readFileSync } from "node:fs"
import { homedir } from "node:os"

const RATE_MS = 5 * 60 * 1000
const QUOTA_MS = 6 * 60 * 60 * 1000
const RESEND_MS = 30 * 1000
const MAX_RESENDS = 4
const CONTINUE = "The previous model hit a service limit. Continue the existing task from the conversation and current workspace state. Preserve completed work; do not repeat completed actions."
const QUOTA_RE = /quota|usage limit|credit limit|billing|plan limit|limit reached/i
const RATE_RE = /rate.?limit|too many requests|429|high concurrency|overloaded|temporarily unavailable/i

function readJson(path) {
  try { return JSON.parse(readFileSync(path, "utf8")) } catch { return null }
}

function buildFallbacks() {
  const home = homedir()
  const cfg = readJson(`${process.env.XDG_CONFIG_HOME || `${home}/.config`}/opencode/opencode-models.json`)
    ?? readJson(`${home}/.local/config/opencode-models.json`)
  // No hardcoded emergency list: free tiers rotate, and config is the authority.
  const preferred = Array.isArray(cfg?.free_models)
    ? cfg.free_models.filter((m) => typeof m === "string" && /^opencode\/[^\s/]+$/.test(m)) : []
  const available = readJson(`${home}/.local/state/agents/opencode-agent-models.json`)?.available
  return Array.isArray(available) ? preferred.filter((m) => available.includes(m)) : preferred
}

function classifyText(text) {
  if (typeof text !== "string") return null
  if (QUOTA_RE.test(text)) return "quota"
  if (RATE_RE.test(text)) return "rate"
  return null
}

function classifyError(error) {
  if (!error || ["MessageAbortedError", "ProviderAuthError"].includes(error.name)) return null
  const data = error.data || {}
  if (data.statusCode === 401 || data.statusCode === 403) return null
  if (data.statusCode === 402) return "quota"
  if (data.statusCode === 429 || data.statusCode === 408 || (data.statusCode >= 500 && data.statusCode < 600)) return "rate"
  return classifyText(data.message)
}

function cooldownMs(kind, data) {
  const value = data?.responseHeaders?.["retry-after"] ?? data?.responseHeaders?.["Retry-After"]
  const delay = /^\d+$/.test(value || "") ? Number(value) * 1000 : Date.parse(value) - Date.now()
  return Math.min(QUOTA_MS, Math.max(kind === "quota" ? QUOTA_MS : RATE_MS, Number.isFinite(delay) ? delay : 0))
}

function isContinuation(message) {
  return message.parts?.some((p) => p.type === "text" && p.synthetic === true && p.text === CONTINUE)
}

export const ModelFallbackPlugin = async ({ client }) => {
  // CLI wrappers handle failures themselves; background prompts race their exits.
  if (process.env.DOTFILES_OPENCODE_NO_FALLBACK === "1") return {}
  const fallbacks = buildFallbacks()
  const cooldownUntil = new Map()
  const turns = new Map()
  const inFlight = new Set()
  const log = async (message) => {
    try { await client.app.log({ body: { service: "model-fallback", level: "warn", message } }) } catch {}
  }
  const messagesFor = async (sessionID) => {
    const result = await client.session.messages({ path: { id: sessionID }, throwOnError: true })
    const messages = result?.data ?? result
    return Array.isArray(messages) ? messages : []
  }

  async function recover(sessionID, kind, data) {
    if (!sessionID || !fallbacks.length || inFlight.has(sessionID)) return
    inFlight.add(sessionID) // Before the first await: duplicate error events coalesce.
    try {
      const messages = await messagesFor(sessionID)
      const users = messages.filter((m) => m.info?.role === "user")
      const lastUser = users.at(-1)
      const original = users.findLast((m) => !isContinuation(m))
      if (!lastUser || !original?.info.id || !lastUser.info.agent) return
      let turn = turns.get(sessionID)
      if (turn?.id !== original.info.id) {
        turn = { id: original.info.id, count: 0, lastAt: 0 }
        turns.set(sessionID, turn)
      }
      const now = Date.now()
      if (turn.count >= MAX_RESENDS || (turn.count && now - turn.lastAt < RESEND_MS)) return
      const lastAssistant = messages.findLast((m) => m.info?.role === "assistant" && m.info.parentID === lastUser.info.id)
      if (lastAssistant?.info.finish === "stop" && !lastAssistant.info.error) return
      const failed = lastAssistant?.info.modelID
        ? { providerID: lastAssistant.info.providerID, modelID: lastAssistant.info.modelID }
        : lastUser.info.model
      if (!failed?.providerID || !failed?.modelID) return
      cooldownUntil.set(`${failed.providerID}/${failed.modelID}`, now + cooldownMs(kind, data))
      const target = fallbacks.find((m) => (cooldownUntil.get(m) || 0) <= now)
      if (!target) return
      // Do not abort a newer user turn that arrived while fetching history.
      const latest = (await messagesFor(sessionID)).findLast((m) => m.info?.role === "user")
      if (latest?.info.id !== lastUser.info.id) return
      turn.count += 1
      turn.lastAt = now
      await client.session.abort({ path: { id: sessionID }, throwOnError: true })
      const afterAbort = (await messagesFor(sessionID)).findLast((m) => m.info?.role === "user")
      if (afterAbort?.info.id !== lastUser.info.id) return
      const [providerID, modelID] = target.split("/")
      // Keep the agent/tool constraints. Original text, attachments and completed
      // tool calls remain in session history; resending the task can repeat edits.
      await client.session.promptAsync({
        path: { id: sessionID },
        body: {
          model: { providerID, modelID }, agent: lastUser.info.agent,
          system: lastUser.info.system, tools: lastUser.info.tools, format: lastUser.info.format,
          parts: [{ type: "text", text: CONTINUE, synthetic: true }],
        },
        throwOnError: true,
      })
      await log(`session ${sessionID}: continuing on ${target} after ${kind} limit`)
      try {
        await client.tui.showToast({ body: { message: `Model limit — continuing on ${target}`, variant: "warning" } })
      } catch {}
    } catch (error) {
      await log(`session ${sessionID}: fallback failed (${error?.name || "error"})`)
    } finally {
      inFlight.delete(sessionID)
    }
  }

  return {
    event: async ({ event }) => {
      const props = event.properties || {}
      if (event.type === "session.deleted") {
        turns.delete(props.info?.id ?? props.sessionID)
      } else if (event.type === "session.status" && props.status?.type === "retry") {
        const kind = classifyText(props.status.message)
        if (kind === "quota" || (kind === "rate" && props.status.attempt >= 2)) {
          await recover(props.sessionID, kind, {})
        }
      } else if (event.type === "session.error") {
        const kind = classifyError(props.error)
        if (kind) await recover(props.sessionID, kind, props.error.data)
      }
      // idle also fires for aborts and failures; it must not reset the retry cap.
    },
  }
}
