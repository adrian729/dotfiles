# Step 04 — Chat

**Goal** CodeCompanion's native ACP chat buffer in a side panel, with options preset at session creation rather than switched afterwards.

**Files** `nvim/.config/nvim/lua/ai/chat.lua`

**Depends on** 01 (adapters, providers).

**Evidence** `findings.md` → *Session config options are settable declaratively*, *Process and session costs*, *Plugin-source gotchas → Adapters and connections*.

## Design

No CLI terminal surface — the ACP chat buffer is the single chat surface, and `interactions.cli` stays deliberately unused. Tools, diffs and permission prompts render in-buffer, and agentic behaviour is *wanted* here. This is exactly why opencode's tool use is fine in chat and wrong in inline.

- new chats are created programmatically so options are preset at session creation: `adapters.resolve(name, { session_config_options = { model = …, thought_level = …, mode = … } })`, then `interactions.chat.new({ adapter = … })`
- claude's `agent` option has `category: null`, so it is unreachable declaratively — apply it after the session exists via `conn:set_config_option("agent", name)`
- live switching keeps the plugin's own affordances: `ga` (adapter + model), `/acp_session_options` (mode, effort, fast, agent), `gd` (debug window showing the raw option set)
- ollama chat uses the HTTP adapter with the same endpoint/model/think options
- each chat buffer is independent; the status panel (step 05) edits the focused chat, or the defaults for the next one when none is focused

Chat connections are **not** in the inline pool. A chat restoring history on a shared connection would swallow inline updates, because the session-loading branch outranks the active-prompt branch.

Note each new claude session costs ~19k cached-write tokens — it loads the Claude Code system prompt plus this repo's `CLAUDE.md`/`AGENTS.md`. Sessions are cheap in wall time on a warm process but not free, and a reused session accumulates every prior edit in its history. Prefer a new chat over a long-lived one for unrelated work.

Kept from the current config: the 90s ACP timeout, and `<leader>cq` to close all chats. Dropped: the `env.CLAUDE_CODE_OAUTH_TOKEN` declaration.

## Done when

- a new chat on each provider comes up with the preset model/effort/mode already applied — confirm in the `gd` debug window, not by asking the model
- claude's `agent` is applied and visible in `gd` after session creation
- `ga` and `/acp_session_options` still work on a programmatically created chat
- `<leader>cq` closes all chats, including one mid-response
- opening a chat while an inline request is in flight does not disturb the inline request, and vice versa
