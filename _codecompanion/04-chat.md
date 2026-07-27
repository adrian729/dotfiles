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

## Keymaps this step owns

Step 01 bound `<leader>cc` to the plugin-native `:CodeCompanionChat Toggle` so the editor was usable during the rebuild. This step takes it over and adds the rest:

- `<leader>cc` — **replaces** step 01's native binding with a toggle of the last chat, showing a message when there is none
- `<leader>cn` — new chat with the current provider and preset options
- `<leader>cq` — close all chats

`<leader>ca` stays exactly as step 01 left it. The action palette is plugin-native and there is nothing for us to add.

Carried over in spirit from the old config, which step 00 deleted: the 90s ACP timeout (now set in step 01's adapters) and `<leader>cq`. Not carried over: the `env.CLAUDE_CODE_OAUTH_TOKEN` declaration.

## Done when

- **step 03's prose float is upgraded**: `<CR>` now opens a chat pre-loaded with the selection and the exchange, instead of the bare `:CodeCompanionChat` fallback it shipped with
- a new chat on each provider comes up with the preset model/effort/mode already applied — confirm in the `gd` debug window, not by asking the model
- claude's `agent` is applied and visible in `gd` after session creation
- `ga` and `/acp_session_options` still work on a programmatically created chat
- `<leader>cq` closes all chats, including one mid-response
- `<leader>cc` toggles the last chat and says so when there is none, rather than opening a bare plugin chat as it did after step 01
- `<leader>cn` opens a new chat with the current provider's preset options
- opening a chat while an inline request is in flight does not disturb the inline request, and vice versa
