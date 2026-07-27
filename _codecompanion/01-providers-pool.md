# Step 01 — Providers, adapters, connection pool

**Goal** The single source of truth for what providers exist and what options they carry, the adapter definitions every other step builds on, and a connection pool that makes concurrent ACP inline possible.

**Files**

- `nvim/.config/nvim/lua/ai/providers.lua`
- `nvim/.config/nvim/lua/ai/acp_pool.lua`
- `nvim/.config/nvim/lua/ai/debug.lua` — the smoke harness below
- adapter definitions and two keymaps in `nvim/.config/nvim/lua/plugins/codecompanion.lua`, which step 00 left bare

**Depends on** 00. Everything else depends on this.

**Ends the blackout.** Step 00 leaves the plugin with no working adapter; restoring them here brings back the plugin's native chat. Bind `<leader>cc` (`:CodeCompanionChat Toggle`) and `<leader>ca` (`:CodeCompanionActions`) as one-line plugin-native mappings while you are here — they need nothing from us, and they make the editor useful again three steps before `chat.lua` exists. Step 04 replaces `cc` with the new-style toggle; `ca` stays plugin-native for good.

**Evidence** `findings.md` → *Concurrency*, *Process and session costs*, *Provider capability matrix*, *Session config options are settable declaratively*, *Plugin-source gotchas → Adapters and connections*.

Adapter definitions live here rather than with chat (step 04) because the pool spawns connections *from* adapters — putting them later would make inline depend on a step that comes after it.

## providers.lua

The provider and option schema is in `README.md` → *Providers*; this module is its runtime form. It owns the schema, the dynamically resolved model lists (cached per nvim session), the current selection for inline and for chat, and the defaults. Inline, chat and status all read it, which is what makes the option UX shared rather than reimplemented three times.

It also exposes each transport's **reach**, from `findings.md` → *Transport reach*, so the status panel can render a marker and `cI` can refuse on a transport that cannot read. Derive it from the provider/transport pair rather than hardcoding it per keymap.

## Adapter definitions

One ACP adapter per provider, not per keymap — `ci` and `cI` differ only in prompt text.

**claude** — start from the stock `claude_code` adapter and override:

- `parameters.clientCapabilities.fs = { readTextFile = false, writeTextFile = false }`. This is hygiene, not enforcement: the capability is inert (`findings.md` → *The `fs` capability is inert*). Advertise nothing we do not intend to serve.
- `env = {}` — drops `CLAUDE_CODE_OAUTH_TOKEN`, unnecessary since `authMethods` is empty. Note this does *not* keep the variable from the agent: the child inherits the parent environment regardless. It was also **not** the cause of the old `_establish_session` stalls — that was a stale `claude-agent-acp` 0.55.0 that `ensure_nvm_path()` put ahead of Homebrew's 0.59.0 on `PATH` (`findings.md`).
- `defaults.timeout = 90000` — **must** be restated; the stock value is 20s.
- `session_config_options = { mode = "dontAsk" }` for every inline session, not just `cI`. This is the actual write defence.
- do **not** wire `commands.yolo`.

**opencode** — the stock ACP adapter plus `OPENCODE_PERMISSION` in the environment, denying `edit`/`write`/`patch`/`bash` while allowing `read`/`grep`/`glob`/`list`. Deny-everything is not an option: it leaks `<tool_call>` markup as message text, and in one run stopped the process initialising at all. Allow-everything is not an option either: opencode edited a file on disk with zero permission requests. Same 90s timeout restatement.

Pin the model. The `auto` entry in the model list means "let `opencode-llm` walk its own free-tier fallback list", which is meaningful on the relay and meaningless on an ACP session — leaving it unset there lands on opencode's ambient default, currently `opencode/big-pickle`. On the ACP path `auto` resolves to the head of the relay list instead.

**ollama** — the stock HTTP adapter, with `env.url` `http://localhost:11434` for local and `https://ollama.com/api/chat` plus an `Authorization: Bearer $OLLAMA_API_KEY` header for cloud. Two schema defaults carry over from the adapter step 00 deleted, and both matter:

- `num_ctx = 16384` — ollama's own default is small enough to silently truncate a real refactor. Losing this degrades output with no error.
- `keep_alive = "30m"` — keeps the local model warm between calls. Without it every local inline request pays a reload.

`model` and `think` were functions reading `vim.g.ollama_inline_model` / `vim.g.ollama_think`; they now read `providers.lua` instead, and those globals do not come back.

**Default strategies.** Adapter definitions alone do not make `:CodeCompanionChat` work — the plugin still picks its own default, which is `copilot` and which this machine has no credentials for. Set `interactions.chat.adapter = "claude_code"` in `setup()` as well. This is what actually ends the blackout; step 04 later creates chats programmatically and stops depending on the default, but the default still backs the plain `:CodeCompanionChat` command and step 03's degraded prose fallback.

Set `interactions.inline.adapter` and `interactions.cmd.adapter` to plain `ollama` for the same reason. Both the `:CodeCompanion` and `:CodeCompanionCmd` commands survive the strip and would otherwise inherit that same `copilot` default. The built-in inline is superseded by step 03 and the `ollama_inline` JSON-schema variant does not come back, but `:CodeCompanionCmd` is explicitly kept (step 03 → *Out of scope*) and needs a working HTTP adapter.

On every inline ACP connection, override `handle_fs_write_file_request` to refuse. Nothing exercises that path today, so this is insurance against a future version rather than protection — but it removes a latent whole-buffer clobber for one function. Assert the method exists at pool init; if upstream has renamed or inlined it, the override silently stops working, so fail loudly rather than fail open.

## acp_pool.lua

- **Lazy**: nothing spawns at nvim startup. First use of a provider spawns it (~1.2s claude, ~0.8s opencode).
- **One warm primary connection per provider**, created the documented way: `Connection.new{ adapter }` → `connect_and_authenticate()` → `ensure_session()`. No patched internals. Both inline keymaps share the pool, since they differ only in prompt.
- **Overflow on demand**: a second concurrent request on the same provider spawns its own connection, paying ~1.2s and ~132 MB (claude) or ~536 MB (opencode) only while it overlaps. Hard cap of 3 per provider; further requests queue FIFO.
- **Idle reap**: overflow after ~60s idle, the primary after 15 minutes, respawned transparently on next use. This is what keeps opencode's 536 MB from lingering.
- **Coroutine requirement**: all connection and session setup must run inside a coroutine. Outside one, `send_rpc_request` falls back to a `vim.wait` busy-loop up to the 90s timeout and freezes the editor.
- **Per-request watchdog**, ours and not the plugin's: any request producing no completion inside its timeout resolves as an error and clears its virtual text. It must be armed **before** the connection exists, since a wedged agent can accept `initialize` and never answer `session/new`, and re-armed when the prompt goes on the wire so queueing does not eat the reply's budget. This also bounds the case where a permission request arrives with no active prompt and is dropped without a reply, leaving the agent waiting forever.
- **Completion callbacks are deferred out of the plugin's stack** with `vim.schedule`. `handle_done` clears `_active_prompt` *after* calling the completion handler, so a callback that starts the next prompt inline gets that prompt silently discarded — see `findings.md`. Releasing the connection has the same hazard, since it can pump a queued request.
- **Process death is hooked through the adapter's `handlers.on_exit`** on the per-spawn adapter copy, and flagged synchronously so the crash is reported as a crash rather than as a cancel.
- **Teardown**: `pcall` the `disconnect()` — it throws on an already-dead handle, which the reaper hits every cycle — and clear our own state regardless. Use our own augroup; the plugin's per-connection `VimLeavePre` autocmds accumulate and are not ours to remove.
- **Chat connections stay out of this pool.** A chat restoring history on a shared connection would swallow inline updates, because the session-loading branch outranks the active-prompt branch.
- Each spawn opens an RPC log file; they accumulate one per spawn and want occasional pruning.

Because each connection owns exactly one session, a crashed agent takes down exactly one request, and `PromptBuilder:cancel()` is correct without a workaround. Hook crash handling to the adapter's public `handlers.on_exit`.

## Smoke harness

This step has no user-facing entry point — inline arrives in 03 — so it ships its own way to be exercised. Without this, step 01 cannot be verified when it is finished, only much later and tangled with inline's own bugs.

- `:AiPoolStatus` — one line per live connection: provider, state, session id, age, idle time, whether it is primary or overflow, and the queue depth.
- `:AiDebugSend {provider} {prompt}` — sends a prompt through the pool and shows the raw reply in a scratch buffer. No parsing, no placement, no buffer mutation. This is the seam where a transport problem is distinguishable from a parsing or placement problem, which is worth keeping well past step 03.

Both stay in the final build. They cost little and they are the first thing to reach for when a later step misbehaves.

Mind the lazy-loading trap: the plugin spec loads on `cmd`/`keys`, and if these commands are only registered inside `config()` they will not exist until something *else* loads the plugin first — which at this step is nothing. Add `AiPoolStatus` and `AiDebugSend` to the spec's `cmd` list so lazy.nvim registers stubs that trigger the load.

## Done when

Every check below is runnable with only this step built.

- nothing is spawned at nvim startup — `:AiPoolStatus` is empty and `ps` is clean until the first `:AiDebugSend`
- one `:AiDebugSend claude …` spawns a connection in ~1.2s and returns the reply; a second reuses it, visible as an unchanged session id
- three concurrent `:AiDebugSend` calls produce exactly three connections with no cross-talk — each reply matches its own prompt — and a fourth shows as queued rather than spawning
- overflow connections disappear ~60s after going idle and the primary after 15 minutes, both visible in `:AiPoolStatus`; the next send respawns transparently
- `kill -9` on one agent process mid-prompt fails only its own request; the others complete
- a request whose agent never replies is resolved as an error by the watchdog, not left hanging
- pool init aborts with a clear message if `handle_fs_write_file_request` is missing from the client
- spawning an overflow connection never blocks the UI — type during the spawn and confirm no freeze
- `<leader>cc` opens a working chat on the claude adapter, and `ga`/`gd` work inside it — this is what ends the step 00 blackout
- `<leader>ca` opens the action palette
- no other `<leader>c*` key is bound yet — `:map <leader>c` lists exactly those two
