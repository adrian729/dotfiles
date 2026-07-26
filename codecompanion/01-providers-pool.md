# Step 01 — Providers, adapters, connection pool

**Goal** The single source of truth for what providers exist and what options they carry, the adapter definitions every other step builds on, and a connection pool that makes concurrent ACP inline possible.

**Files**

- `nvim/.config/nvim/lua/ai/providers.lua`
- `nvim/.config/nvim/lua/ai/acp_pool.lua`
- adapter definitions in `nvim/.config/nvim/lua/plugins/codecompanion.lua`

**Depends on** nothing. Everything else depends on this.

**Evidence** `findings.md` → *Concurrency*, *Process and session costs*, *Provider capability matrix*, *Session config options are settable declaratively*, *Plugin-source gotchas → Adapters and connections*.

Adapter definitions live here rather than with chat (step 04) because the pool spawns connections *from* adapters — putting them later would make inline depend on a step that comes after it.

## providers.lua

The provider and option schema is in `00-overview.md` → *Providers*; this module is its runtime form. It owns the schema, the dynamically resolved model lists (cached per nvim session), the current selection for inline and for chat, and the defaults. Inline, chat and status all read it, which is what makes the option UX shared rather than reimplemented three times.

It also exposes each transport's **reach**, from `findings.md` → *Transport reach*, so the status panel can render a marker and `cI` can refuse on a transport that cannot read. Derive it from the provider/transport pair rather than hardcoding it per keymap.

## Adapter definitions

One ACP adapter per provider, not per keymap — `ci` and `cI` differ only in prompt text.

**claude** — start from the stock `claude_code` adapter and override:

- `parameters.clientCapabilities.fs = { readTextFile = false, writeTextFile = false }`. This is hygiene, not enforcement: the capability is inert (`findings.md` → *The `fs` capability is inert*). Advertise nothing we do not intend to serve.
- `env = {}` — drops `CLAUDE_CODE_OAUTH_TOKEN`, the most plausible cause of the old `_establish_session` stalls, and unnecessary since `authMethods` is empty.
- `defaults.timeout = 90000` — **must** be restated; the stock value is 20s.
- `session_config_options = { mode = "dontAsk" }` for every inline session, not just `cI`. This is the actual write defence.
- do **not** wire `commands.yolo`.

**opencode** — the stock ACP adapter plus `OPENCODE_PERMISSION` in the environment, denying `edit`/`write`/`patch`/`bash` while allowing `read`/`grep`/`glob`/`list`. Deny-everything is not an option: it leaks `<tool_call>` markup as message text, and in one run stopped the process initialising at all. Allow-everything is not an option either: opencode edited a file on disk with zero permission requests. Same 90s timeout restatement.

**ollama** — the stock HTTP adapter. Cloud differs from local only by `env.url` (`https://ollama.com/api/chat`) and an `Authorization: Bearer $OLLAMA_API_KEY` header.

On every inline ACP connection, override `handle_fs_write_file_request` to refuse. Nothing exercises that path today, so this is insurance against a future version rather than protection — but it removes a latent whole-buffer clobber for one function. Assert the method exists at pool init; if upstream has renamed or inlined it, the override silently stops working, so fail loudly rather than fail open.

## acp_pool.lua

- **Lazy**: nothing spawns at nvim startup. First use of a provider spawns it (~1.2s claude, ~0.8s opencode).
- **One warm primary connection per provider**, created the documented way: `Connection.new{ adapter }` → `connect_and_authenticate()` → `ensure_session()`. No patched internals. Both inline keymaps share the pool, since they differ only in prompt.
- **Overflow on demand**: a second concurrent request on the same provider spawns its own connection, paying ~1.2s and ~132 MB (claude) or ~536 MB (opencode) only while it overlaps. Hard cap of 3 per provider; further requests queue FIFO.
- **Idle reap**: overflow after ~60s idle, the primary after 15 minutes, respawned transparently on next use. This is what keeps opencode's 536 MB from lingering.
- **Coroutine requirement**: all connection and session setup must run inside a coroutine. Outside one, `send_rpc_request` falls back to a `vim.wait` busy-loop up to the 90s timeout and freezes the editor.
- **Per-request watchdog**, ours and not the plugin's: any request producing no completion inside its timeout resolves as an error and clears its virtual text. This also bounds the case where a permission request arrives with no active prompt and is dropped without a reply, leaving the agent waiting forever.
- **Teardown**: `pcall` the `disconnect()` — it throws on an already-dead handle, which the reaper hits every cycle — and clear our own state regardless. Use our own augroup; the plugin's per-connection `VimLeavePre` autocmds accumulate and are not ours to remove.
- **Chat connections stay out of this pool.** A chat restoring history on a shared connection would swallow inline updates, because the session-loading branch outranks the active-prompt branch.
- Each spawn opens an RPC log file; they accumulate one per spawn and want occasional pruning.

Because each connection owns exactly one session, a crashed agent takes down exactly one request, and `PromptBuilder:cancel()` is correct without a workaround. Hook crash handling to the adapter's public `handlers.on_exit`.

## Done when

- nothing is spawned at nvim startup (`ps` clean until first use)
- first inline request on a provider spawns one connection in ~1.2s and reuses it on the next request
- three concurrent claude inline requests produce exactly three connections, with no cross-talk between them, and a fourth queues rather than spawning
- overflow connections are gone ~60s after going idle; the primary is gone after 15 minutes; the next request respawns transparently
- killing an agent process mid-prompt fails only its own request — the others complete
- a request whose agent never replies is resolved as an error by the watchdog, not left hanging
- pool init aborts with a clear message if `handle_fs_write_file_request` is missing from the client
- spawning an overflow connection never blocks the UI (verify by typing during the spawn)
