# CodeCompanion Integration Plan

## Context

The current nvim AI setup (`nvim/.config/nvim/lua/plugins/codecompanion.lua`) works but is unpleasant to use: inline edits run on local ollama and take up to two minutes, the model decides where its own output lands (so it can nuke a whole file), claude/opencode are chat-only, and every provider has a different, ad-hoc switching UX. This plan rebuilds the integration from zero around a single idea: **nvim owns placement, the model only supplies code**, with one shared option UX across all providers.

Everything below is grounded in two passes. First, live probes of `claude-agent-acp` 0.59.0, `opencode acp` 1.18.0, the ollama cloud API and the repo's own `opencode-llm` relay — facts marked *measured* were timed on this machine, not assumed. Second, an audit of the installed plugin source (commit `d34edce`) to check that CodeCompanion's ACP **client** can actually do what the protocol allows and that its stock adapters behave the way the probes did. Several did not, and those findings are called out below; citations of the form `acp/init.lua:685` are relative to `~/.local/share/nvim/lazy/codecompanion.nvim/lua/codecompanion/`.

## Verified findings

### Inline cannot use ACP adapters (built-in)

`interactions/inline/init.lua:208` hard-gates on `self.adapter.type ~= "http"`, same gate in `interactions/cmd.lua:29`, and `doc/configuration/inline.md` states it. Inline goes through `codecompanion.http` (curl); ACP is a stdio JSON-RPC subprocess. Not a config problem.

**But every API needed to build ACP inline ourselves is public and chat-agnostic:**

- `require("codecompanion.acp").new({ adapter = ... })` → `:connect_and_authenticate()` → `:session_prompt(messages)` returns a builder with `:on_message_chunk()`, `:on_tool_call()`, `:on_permission_request()`, `:on_complete()`, `:on_error()`, `:with_options({ bufnr, interaction })`, `:send()` (pattern from `interactions/chat/acp/handler.lua:207`).
- `require("codecompanion.helpers").show_diff({ bufnr, from_lines, to_lines, inline = true, banner, keymaps = { on_accept, on_reject }, skip_default_keymaps = true })` renders the same inline diff the built-in uses. `skip_default_keymaps` is what lets us own `g2`/`g3` for concurrency.

`show_diff` **renders and tracks a diff; it does not apply or revert anything.** `DiffUI` has no accept or reject method — `diff/keymaps.lua:67-85` dispatches to the `on_accept`/`on_reject` callbacks *we* supply, exactly as the built-in does at `interactions/inline/init.lua:817-821`. All buffer mutation is ours to write.

### The `fs` capability must be set explicitly — and writes are not enforced

The stock claude adapter advertises full filesystem access:

```lua
-- adapters/acp/claude_code.lua:31-36
parameters = {
  protocolVersion = 1,
  clientCapabilities = {
    fs = { readTextFile = true, writeTextFile = true },
  },
```

The spike below measured claude as well-behaved because the *probe* declared `fs` off. Using the stock adapter would give plain inline requests full repo read and write, which is the opposite of the contract this plan is built on.

Worse, the client honours write requests without checking either the capability it declared or the user. `handle_fs_write_file_request` (`acp/init.lua:771`) validates only `sessionId` and the param types, then calls `fs.write_text_file(path, content)` and fires `FileEdited` **after the fact**. No permission prompt exists anywhere in that path. So **declaring `writeTextFile = false` is advisory to a well-behaved agent, not enforcement.**

Because `clientCapabilities` is sent at `initialize`, it is fixed **per process**. The text-only and repo-reading inline variants therefore cannot share a connection — see *Inline / Cmd mode* and the pool design below.

### Spike result: the text-only contract holds

Six cases per agent — long-selection rename, conversational question, deliberate tool temptation, cursor-insert, impossible request, no-op — plus the same rename against the cloud models. Every ACP row was probed with `fs` explicitly **off**, per the finding above.

| Backend | 57-line rename | verbatim? | fences | tools used |
|---|---|---|---|---|
| ollama cloud `gpt-oss:20b` | **2.22s** | yes | no | n/a |
| ollama cloud `gpt-oss:120b` | **3.93s** | yes | no | n/a |
| claude ACP (`fs` off) | **5.12s** | yes | ` ```lua ` | **none, in all 6 cases** |
| opencode ACP | 9.45s → 10.42s | yes | no → yes | see below, and drifted |
| opencode relay (`opencode-llm`) | ~9.3s (small edit) | yes | no | none, by construction |
| ollama local `qwen3-coder:30b` | ~119s (from log) | — | — | n/a |

**The opencode row has already drifted between probe runs.** The first pass saw it run `grep`/`read`/`glob`/`bash` and return bare code; a later pass on the same prompts saw no tools at all and fenced code, at comparable latency. Most likely its ambient default model changed. Treat every opencode number here as perishable — this is the strongest argument for the durable capability probe in *Build order*.

Four behaviours the design has to accommodate:

1. **Claude returns prose when it shouldn't edit** — 3 of 6 cases. It explained the code when asked a question, and *refused* rather than guessing when asked to match a repo pattern with tools off. Correct behaviour, but prose must never be inserted into a buffer.
2. **Fence handling differs and is not stable.** Claude wraps in ` ```lua `, the ollama models return bare code, and opencode has been observed doing both. With tools enabled claude also prefixes prose before the fence. The parser must extract the fenced block when one is present, not trust the whole reply.
3. **opencode over ACP cannot be made cleanly tool-free.** It ignored "do not use any tools", ran `grep`/`read`/`glob`/**`bash`** against the repo, and raised **zero** permission requests — so auto-denial never gets a say. Setting session mode to `plan` did not stop it. `OPENCODE_PERMISSION` does reach an ACP session, but the result is worse rather than better: with tools denied the model still attempts one, nothing parses the attempt, and raw `<tool_call><function=grep>…` leaks into the message text where inline would insert it into the buffer.
4. **Neither agent asks permission for reads, so permission handling is not a safety mechanism.** With `fs` advertised, claude ran Terminal tools and raised zero permission requests too (27s, prose prefixed before the fenced code). Denying writes cannot rely on answering `session/request_permission` — nothing arrives to answer. It has to come from the session **mode**, or from not advertising the capability at all.

### `dontAsk` refuses writes, including shell escapes (measured)

Whether claude's `dontAsk` mode genuinely refuses writes gated the whole repo-reading inline variant. Tested three ways, with the verdict taken from the bytes on disk rather than from what the agent claimed:

| Configuration | Agent behaviour | File on disk |
|---|---|---|
| `fs` write **true** + `dontAsk` | ran `Terminal` (read-only `ls`/`cat`), `Read`, then `Edit` — Edit denied by the harness | **unmodified** |
| `fs` write **false** + `dontAsk` | `Read`, then `Edit` — denied | **unmodified** |
| `fs` write **false** + `dontAsk`, explicitly instructed to write via `echo … >> file` | Bash denied outright: *"Permission to use Bash has been denied because Claude Code is running in don't ask mode"* | **unmodified** |

Zero permission requests in all three, consistent with finding 4 above.

The third row is the decisive one. In the first row a read-only Bash command *succeeded* under the same mode, so `dontAsk` is not a blanket tool block — it classifies per invocation and denies the mutating ones, shell redirects included. That makes the repo-reading variant **structurally** safe rather than safe-by-model-restraint.

Caveat: this enforcement lives in `claude-agent-acp`'s permission classifier, not in our client. It is version-dependent, which is why the capability probe tracks it.

### Concurrency: one session per connection, so concurrency means processes

ACP the protocol multiplexes sessions over one process — measured: two prompts on **two** sessions of one process run genuinely in parallel (claude 2.73s + 4.11s of work in 4.11s wall; opencode 2.56s wall). Two prompts on **one** session cannot be attributed, since `session/update` carries only a `sessionId`.

CodeCompanion's client cannot do that multiplexing. `Connection` holds `session_id` as a scalar and `_active_prompt` as a single slot, `start_agent_process()` spawns a subprocess per `Connection`, and `handle_incoming_request_or_notification` (`acp/init.lua:685`) **drops every message whose `sessionId` isn't the active one** — notifications silently, requests with an `invalid sessionId` error.

Multiplexing anyway was evaluated and rejected. It requires overriding `handle_incoming_request_or_notification` and `store_rpc_response`, managing `_active_prompt` and `session_id` by hand around every send, and relying on the *ordering* of the `stopReason` check inside `handle_rpc_message:585` — which, if upstream reorders it, silently stops completions from ever firing. It also cannot serve two different `fs` capabilities, which are fixed per process.

**So concurrent inline means concurrent connections.** Measured marginal cost, which gets no page-sharing benefit — each process costs full price, and the system-wide delta is worse than the RSS sum:

| Processes | RSS each | Cumulative system delta |
|---|---|---|
| 1 | 132.8 MB | 140 MiB |
| 2 | 131.8 MB | 354 MiB |
| 3 | 132.0 MB | 655 MiB |

This constraint applies to **claude only**. ollama cloud is plain HTTP with no sessions, and the opencode relay forks a subprocess per call — both are already unboundedly concurrent.

### Process and session costs (measured)

| | claude-agent-acp | opencode acp |
|---|---|---|
| spawn → `initialize` | 0.13s | 0.56s |
| `session/new`, cold process | 1.31s | 0.20s |
| `session/new`, warm process | 0.95s | 0.00s |
| spawn + handshake + session, end to end | 1.12–1.26s | — |
| idle RSS | 133 MB | **536 MB** (667 MB after two prompts) |

Claude reported `cachedWriteTokens: 19151` on a session's first prompt — every new claude session loads the Claude Code system prompt plus this repo's `CLAUDE.md`/`AGENTS.md`. Sessions are cheap in time on a warm process, but not free in tokens, and a reused session accumulates every prior edit in its history.

### Provider capability matrix (probed)

| | claude-agent-acp 0.59.0 | opencode acp 1.18.0 | ollama local | ollama cloud |
|---|---|---|---|---|
| model | `default`/`sonnet`/`fable`/`opus`/`haiku` | 41 ids | 4 installed | free tier of the account key |
| effort | `thought_level`: default→max | — | — | — |
| fast mode | `model_config`: on/off | — | — | — |
| permission mode | auto/default/acceptEdits/plan/dontAsk/bypassPermissions | build/plan | — | — |
| tool restriction | `dontAsk` denies mutating tools incl. shell | `OPENCODE_PERMISSION` blocks execution but leaks tool-call text | — | — |
| agent | all 45 local subagents | no `--agent` flag on `opencode acp` | — | — |
| thinking | — | — | `think` bool | ignored |
| structured output (`format`) | n/a | n/a | yes | **no** |
| sessions | list/resume/fork/delete/close | list/resume/fork/close | — | — |
| auth | `authMethods: []` → **no OAuth token needed** | shortcircuited in adapter | — | `OLLAMA_API_KEY`, already in env |

ollama cloud is reachable at `https://ollama.com/api/chat` with `Authorization: Bearer $OLLAMA_API_KEY`, same wire format as local — the stock `ollama` HTTP adapter works against it with only an `env.url` and header change. The **local** server cannot proxy cloud models (`Unauthorized`). Free-tier models confirmed reachable: `gpt-oss:20b`, `gpt-oss:120b`, `gemma4:31b`, `nemotron-3-super`.

### Session config options are settable declaratively

`interactions/chat/acp/defaults.lua:49` applies `adapter.defaults.session_config_options` keyed by **category** (`model`, `mode`, `thought_level`, `model_config`), resolving values by id *or* display name, case-insensitively, and accepting functions evaluated at call time (so they can read `vim.g`). Model is applied first because it changes which other options exist. `adapters/acp/init.lua:106-130` merges the option set into the resolved adapter, and `Chat.new{ adapter = … }` accepts the result.

Exception: claude's `agent` option has `category: null`, so it is unreachable that way — it must be set with `conn:set_config_option("agent", name)` after the session exists.

Note that `_apply_config_options` (`acp/init.lua:821`) does a wholesale `self._config_options = config_options`, connection-global. With one session per connection that is harmless, and it is what makes per-request model and mode selection possible.

### Session listing works and is cross-tool

`session/list` on claude returned 84 sessions with `sessionId`, `cwd`, `title`, `updatedAt` — including sessions started in the terminal, not just from nvim. Filterable by `cwd`. opencode supports list/resume/fork too.

`_establish_session` hardcodes `cwd = vim.fn.getcwd()` at creation time, so filtering the picker by `getcwd()` makes sessions vanish whenever nvim is opened in a subdirectory or the user `:cd`s. Filter by git root, matching session `cwd` as a prefix.

### Misc

- The old `_establish_session` timeouts in `codecompanion.log` are **not** explained by cold start — `session/new` measures 1.3s today. The likely cause is the adapter's `env.CLAUDE_CODE_OAUTH_TOKEN` declaration: resolving a missing or keychain-backed variable stalls, and the token is unnecessary since `authMethods` is empty. Override `env = {}` and keep the 90s timeout as insurance.
- The claude adapter also ships `commands.yolo` (`claude-agent-acp --yolo`) — the exact opposite of what the repo-reading variant wants. Do not wire it.
- `Connection:disconnect()` is `assert(self._state.handle):kill(9)` — it **throws** on an already-dead process, which an idle reaper hits every cycle. `pcall` it and clear our own state regardless.
- The plugin registers a `VimLeavePre` autocmd per connection inside `connect_and_authenticate` (`acp/init.lua:149`) in a `clear = false` group and never removes it, so spawn/reap cycles accumulate one dead closure each. Harmless — every one is `pcall`ed onto a dead handle — but our own teardown uses a separate augroup we control.
- `send_rpc_request` yields via `async.wait` when `coroutine.running()`, and otherwise falls back to `wait_for_rpc_response`, which busy-waits on `vim.wait` up to the adapter timeout — 90s in this config. **All connection and session setup must run inside a coroutine** or the editor freezes.
- `DiffUI:setup_keymaps` binds `}` and `{` buffer-locally **even when `skip_default_keymaps` is set** (`diff/ui.lua:193-195`), shadowing the core paragraph motions while a diff is pending, and the second concurrent diff clobbers the first's. Delete both and rebind hunk navigation ourselves.
- With `skip_default_keymaps`, `setup_close_handler` (`diff/ui.lua:533`) also **disables auto-reject on premature close**, so our registry must restore `from_lines` itself on `WinClosed`/`BufDelete` with a diff still pending.
- `strategies` is silently aliased to `interactions` (`config.lua:1377`).
- Diff accept/reject are `g1`/`g2`/`g3` from `interactions.shared.keymaps` (`config.lua:938-957`); the docs' `gda`/`gdr` are stale.
- A third built-in interaction exists that the old plan predates: `interactions.cli`, which runs the real `claude`/`opencode` TUI in a terminal buffer. **Deliberately unused** — the ACP chat buffer is our single chat surface.
- Built-in `display.input` (`interactions/shared/input.lua`) is a cursor-relative floating input with prompt history; reused for the inline prompt.
- `<leader>c` is free of conflicts in `lua/config/keymaps.lua`, whose comment block at lines 150-158 documents the current bindings and must be updated alongside them.
- `lazy.nvim` imports `lua/plugins/*.lua` non-recursively, so implementation modules must live outside that directory.
- `plenary.nvim` is already installed as a CodeCompanion dependency, so a test runner is available at no cost.

## Dependencies

`claude-agent-acp` is what the `claude_code` ACP adapter executes, and on this machine it is a global npm install (`/opt/homebrew/bin/claude-agent-acp` → `@agentclientprotocol/claude-agent-acp`). It was referenced in no installer, so a machine bootstrapped from this repo got no ACP bridge and every claude chat and inline request failed at spawn — the `ENOENT: 'claude-agent-acp'` already visible in `codecompanion.log`. `claude/install.sh` now guards it, alongside an `opencode` presence check, since the opencode chat adapter and the inline relay both shell out to it.

`OLLAMA_API_KEY` is already handled — sourced from `~/.config/ollama/ollama.env` by zsh's nested `.zshenv` — but the ollama **cloud** inline backend depends on it, so nvim must be started from a shell that has it exported.

## Architecture

```
nvim/.config/nvim/
  lua/plugins/codecompanion.lua   lazy spec: deps, keymaps, setup(), adapter defs
  lua/ai/
    providers.lua                 single source of truth: providers, option schemas, defaults, current selection
    acp_pool.lua                  lazy connections, overflow spawning, idle reaping
    inline/init.lua               prompt, placement, extmark anchoring, request registry, diff, accept/reject dispatch
    inline/parse.lua              fence stripping, prose and tool-call-leak detection
    inline/http.lua               ollama_local + ollama_cloud
    inline/acp.lua                claude (text-only, and read-only-tools variant)
    inline/relay.lua              opencode via the `opencode-llm` script
    chat.lua                      new chat with preset options, toggle, close-all
    chat_list.lua                 telescope picker: live chats + resumable sessions
    status.lua                    interactive option panel
    ui.lua                        spinner/virt-text helpers, option-cycling widget, message float
  tests/
    parse_spec.lua                plenary specs over recorded agent replies
    fixtures/                     saved replies: fenced+prose, bare code, leaked tool_call, refusal, question, verbatim rename

claude/.local/scripts/
  acp-capability-probe            re-runnable: regenerates the capability matrix and cost tables
```

`providers.lua` is the keystone — inline, chat and status all read the same schema, which is what makes the UX shared instead of ad-hoc per provider.

### Provider + option schema

Three providers; ollama carries an `endpoint` dimension rather than being split in two.

| Provider | Options (inline) | Options (chat) |
|---|---|---|
| `ollama` | endpoint `local`\|`cloud`, model, think | endpoint, model, think |
| `claude` | model, effort, fast | model, effort, fast, mode, agent |
| `opencode` | model (relay free-tier list) | model, mode |

Model lists resolve dynamically — ollama local from `/api/tags`, ollama cloud from `https://ollama.com/api/tags`, claude from its session `configOptions`, opencode inline from `free_models` in `opencode/.local/config/opencode-models.json` — and are cached per nvim session.

Defaults, free-first per `AGENTS.md`:

- inline: `ollama` / `cloud` / `gpt-oss:120b` — 3.9s on a 57-line selection, free, no local RAM cost
- chat: `claude` / `opus` / effort `xhigh` / mode `acceptEdits`
- opencode: pinned to a free `opencode/*-free` model, never the ambient `big-pickle`

### ACP connection lifecycle

- **Lazy**: nothing spawns at nvim startup. First use of a provider spawns it (~1.2s claude, ~0.8s opencode).
- **One warm primary connection per adapter variant**, created the documented way: `Connection.new{ adapter }` → `connect_and_authenticate()` → `ensure_session()`. No patched internals.
- **Overflow on demand**: a second concurrent request on the same variant spawns its own connection, paying ~1.2s and ~132 MB only while it overlaps. Hard cap of 3 per variant; further requests queue FIFO.
- **Idle reap**: overflow connections after ~60s idle, the primary after 15 minutes, respawned transparently on next use. This is what keeps opencode's 536 MB from lingering when it is used for chat.
- Because each connection owns one session, a crashed agent takes down exactly one request, and `PromptBuilder:cancel()` — which reads `connection.session_id` — is correct without a workaround. Crash handling hooks the adapter's public `handlers.on_exit`.
- Every spawn calls `log.new_response_file()`, so RPC logs accumulate one per spawn and want occasional pruning.
- Chat connections are separate from the inline pool. This is not cosmetic: the `_loading_session and _on_session_update` branch (`acp/init.lua:660`) takes priority over `_active_prompt`, so a chat restoring history on a shared connection would swallow inline updates.
- A **per-request watchdog** in our own registry, independent of the plugin, resolves any request that produces no completion inside its timeout as an error and clears its virtual text.

## Inline / Cmd mode

All backends behind one interface, built together. `ai/inline/init.lua` owns everything except transport; `http.lua`, `acp.lua` and `relay.lua` implement `send(prompt, ctx, callbacks)`.

### The contract

**nvim decides placement; the model returns code only.**

- visual selection → replace exactly that range
- no selection → insert at cursor
- the model never emits `placement`, so it can never route an edit into a chat or a new buffer, and can never widen the edit beyond the anchored range

The prompt embeds the selection, surrounding buffer context, and LSP diagnostics for the range. This replaces both current workarounds — the ollama `format` JSON schema and `FULL_SELECTION_HINT` — and is measured verbatim-clean on all five backends.

### Response parsing

`ai/inline/parse.lua`, in order:

1. If the reply contains a fenced block, extract the **first** fenced block and discard everything around it (claude prefixes prose when tools are on; opencode has been seen fencing too).
2. Otherwise treat the whole reply as code.
3. **Prose detection**: if the result doesn't look like code for the buffer's filetype, do not touch the buffer — hand it to the prose fallback.
4. **Tool-call-leak detection**: a reply containing `<tool_call>` / `<function=…>` markup is a failed tool attempt leaking as text, never code. Reject it the same way as prose.

### Prose fallback

When the model answers instead of editing (claude does this on questions and on refusals — correctly), the buffer is left untouched and the message is shown in a floating window anchored at the target range. `<CR>` opens a chat buffer pre-loaded with the selection and the exchange to continue there; `q` dismisses.

### Concurrency

The built-in snapshots whole-buffer line numbers at send time and sets buffer-local `g2`/`g3`, so two in-flight requests corrupt each other and the last one wins the keymaps. Instead:

- each request anchors its target range with an extmark at send time, so edits landing elsewhere (including another inline accept) shift it correctly
- each in-flight claude request holds its own connection, per the finding above; the HTTP and relay backends are independent by construction
- a per-buffer registry tracks pending requests and rendered diffs
- `show_diff` is called with `skip_default_keymaps = true`; our own `g2`/`g3` dispatch to the diff whose range contains the cursor, calling `require("codecompanion.diff.keymaps").accept_change.callback(diff_ui)` so the plugin's own `resolve_diff` bookkeeping is reused rather than reimplemented
- the `}`/`{` maps the plugin sets anyway are deleted, and hunk navigation moves to `<leader>cj` / `<leader>ck`, dispatched by cursor position like accept/reject
- because auto-reject-on-close is disabled under `skip_default_keymaps`, the registry restores the original lines itself if a buffer or window closes with a diff pending
- if the anchored range is deleted mid-flight, the result is dropped with a notification rather than applied at a guessed position

### Visual feedback

Per-request virtual text at the anchored range (not a cursor-relative float — several must be visible at once): spinner frame, provider/model, and the prompt trimmed with an ellipsis to fit the window. Cleared on completion, error, or cancel.

### Cancellation

`<leader>cx` cancels the request under the cursor, or all in-flight in the buffer. Per transport: ACP sends `session/cancel` through `PromptBuilder:cancel()`; HTTP kills the job handle returned by `Client:request` (`http.lua:378`); the relay kills the `vim.system` handle for the `opencode-llm` subprocess.

### Keymaps and variants

- `<leader>ci` (n, x) — inline prompt, text-only, all backends. The claude adapter variant behind it declares `clientCapabilities.fs = { readTextFile = false, writeTextFile = false }`, which is the configuration the spike measured.
- `<leader>cI` (n, x) — **claude only**: same prompt with `fs = { readTextFile = true, writeTextFile = false }` so it can read the repo, and the session created with mode `dontAsk`. Measured 27s on a context-hungry ask, and it prefixes prose before the fenced code.

  Write safety here is established, not assumed — `dontAsk` denies `Edit` and denies mutating shell commands while leaving reads working (see the measurement table above). Since `clientCapabilities` is fixed at `initialize`, this variant necessarily runs on its own connection, separate from `<leader>ci`'s. As defence in depth, inline connections also override `handle_fs_write_file_request` to refuse, because the client itself does not check the capability it advertised; that override fails open if upstream renames the method, so the pool asserts it exists at init and refuses to enable this variant if it does not.
- `<leader>cm` — switch inline backend/model without opening the status panel
- `<leader>cx` — cancel the request under the cursor, or all in-flight in the buffer
- `g2` / `g3` — accept / reject the diff under the cursor
- `<leader>cj` / `<leader>ck` — next / previous hunk in the diff under the cursor

`:CodeCompanionCmd` is HTTP-only in the plugin too; it stays on the ollama adapter and is out of scope for the custom module.

### Note to revisit: opencode inline transport

Shipping with the **relay** (`opencode run --agent relay --dir <neutral>` — the mechanism behind `opencode-llm`): guaranteed tool-free, no repo access, free model, ~9.3s.

Invoke it by shelling out to the existing `opencode-llm` script rather than composing `opencode run` ourselves. It already handles the free-model fallback walk from `opencode-models.json`'s `relay` list, the neutral cwd, the portable timeout wrapper, and `--format json` parsing — and its contract is exactly what inline needs (content on stdin, prompt as args, answer on stdout). Note `-T` for the timeout and that `-o` is not wanted here.

The reason the relay wins is now specific rather than general. `opencode acp` has no `--agent` flag, and `OPENCODE_PERMISSION` does apply to an ACP session — but denying tools only stops the *execution*, not the attempt, so the model's tool-call markup leaks into the reply as text. The relay pairs the same deny set with a **prompt** telling the model it has no tools, which stops the attempt at source.

**Revisit later.** The concrete next thing to try is overriding the default ACP agent's *prompt* via `OPENCODE_CONFIG_CONTENT` alongside `OPENCODE_PERMISSION`, reproducing the relay's steering inside an ACP session. Also worth re-examining: whether a future opencode release lets a client refuse tools over ACP, and whether the ~9.3s can be cut with a faster free model. If none pan out, reconsider dropping opencode from inline and leaving it chat-only.

## Chat mode

CodeCompanion's native ACP chat buffer in a side panel — no CLI terminal surface. Tools, diffs and permission prompts render in-buffer, and agentic behaviour is *wanted* here, which is exactly why opencode's tool use is fine in chat and wrong in inline.

- new chats are created programmatically so options are preset at session creation: `adapters.resolve(name, { session_config_options = { model = …, thought_level = …, mode = … } })`, then `interactions.chat.new({ adapter = … })`. Claude's `agent` is applied after the session exists via `set_config_option("agent", …)`.
- live switching keeps the plugin's own affordances: `ga` (adapter + model), `/acp_session_options` (mode, effort, fast, agent), `gd` (debug window showing the raw option set)
- ollama chat uses the HTTP adapter with the same endpoint/model/think options
- each chat buffer is independent; the status panel edits the focused chat, or the defaults for the next one when none is focused

Kept from the current config: the 90s ACP timeout, and `<leader>cq` to close all chats. Dropped: the `env.CLAUDE_CODE_OAUTH_TOKEN` declaration.

## Chat list

Telescope picker (telescope + `telescope-fzf-native` are installed and loaded eagerly), prompt at the bottom, `sorting_strategy = "descending"` so best matches sit next to the prompt.

1. **live** — open nvim chats from `interactions.shared.registry`, marked and sorted first
2. **resumable** — past claude/opencode sessions from `session/list`, filtered to the repo by git root rather than `getcwd()`, showing `title` and relative `updatedAt`

Selecting a live chat focuses it. Selecting a past session opens a fresh chat and restores it via `acp_connection:load_session(id)` + `interactions.chat.acp.render.restore_session` (the mechanics `/resume` uses), which must happen before the first message.

Picker actions: open (`<CR>`), close one (`<C-d>`), close all, new chat. History is fetched once per nvim session and cached. Listing reuses a live connection when one exists; otherwise it pays the lazy spawn.

## Status panel

Floating window, one row per option, fully interactive:

```
╭─ AI ─────────────────────────────────╮
│ Inline   ollama · cloud              │
│   model  gpt-oss:120b                │
│   think  off                         │
│ Chat     claude  ◂ opus ▸            │
│   effort xhigh                       │
│   mode   acceptEdits                 │
│   agent  implementer                 │
╰─ ENTER edit · h/l cycle · q close ───╯
```

- `j`/`k` or arrows move between rows
- `<CR>` enters edit mode on a row; `h`/`l` cycle values in place; `<CR>` commits, `<Esc>` reverts
- rows are generated from the provider schema, so a provider gaining an option needs no status-panel changes
- committing applies live to the focused chat's session via `set_config_option`, and updates the stored default for future chats and inline requests
- changing the provider row re-renders the rows below it for that provider's schema
- changing the inline model drains the connection pool rather than mutating a live session

## Key bindings

All under `<leader>c`, which is unused elsewhere in `lua/config/keymaps.lua`.

| Key | Mode | Action |
|---|---|---|
| `<leader>ci` | n, x | Inline prompt (text-only) |
| `<leader>cI` | n, x | Inline prompt with repo reads (claude only) |
| `<leader>cm` | n | Switch inline backend / model |
| `<leader>cx` | n | Cancel inline request(s) |
| `<leader>cj` / `<leader>ck` | n | Next / previous hunk in the diff under the cursor |
| `<leader>cc` | n | Toggle last chat (message if none) |
| `<leader>cn` | n, x | New chat with current provider + options |
| `<leader>cl` | n | Chat list |
| `<leader>cq` | n | Close all chats |
| `<leader>cs` | n | Status panel |
| `<leader>ca` | n, x | Action palette |
| `g2` / `g3` | n | Accept / reject diff under cursor |
| `ga`, `gd`, `/…` | n | Plugin-native, inside the chat buffer |

Two changes from today's bindings: `<leader>ct` is gone, since `think` is a status-panel row like every other provider option, and `<leader>cx` no longer resets a stuck busy flag — it cancels in-flight requests. The comment block at `lua/config/keymaps.lua:150-158` documents these and must be updated with them.

## Build order

The spike that gated this plan is **done**, and so are the two questions it left open — results in *Verified findings*. Remaining work:

1. `ai/providers.lua` + `ai/acp_pool.lua` — schema, model resolution, lazy connections, overflow spawning, idle reaping, watchdog.
2. `ai/inline/parse.lua` + `tests/parse_spec.lua` — fence extraction, prose and tool-call-leak detection, with plenary specs over the recorded replies in `tests/fixtures/`.
3. `ai/inline/*` — placement, extmarks, diff, concurrency, three transports.
4. `ai/chat.lua` + adapter definitions with preset session options and the two `fs` variants.
5. `ai/status.lua`.
6. `ai/chat_list.lua`.
7. `claude/.local/scripts/acp-capability-probe` — consolidate the throwaway probe scripts (handshake dump, phase timing, six-case contract spike, mode behaviour, session listing, marginal process cost, `dontAsk` write enforcement, `OPENCODE_PERMISSION` behaviour) into one re-runnable script that regenerates the matrix and cost tables. Everything they measure is version- and model-dependent: `claude-agent-acp` moved 0.55 → 0.59 during this investigation and gained the whole `configOptions` mechanism the status panel depends on, and opencode's tool-use behaviour changed between two runs days apart.
8. Retire the old `codecompanion.lua` internals; keep only the lazy spec and keymaps, and update the `keymaps.lua` comment block.

## Verification

- inline, per backend, on a 40-line selection: edit lands **only** inside the selection, unchanged lines byte-identical, `g3` restores the buffer exactly
- inline with no selection: code inserted at cursor, nothing else touched
- ask inline a question ("what does this do?") on claude: buffer untouched, message float appears, `<CR>` opens a chat carrying the exchange
- a reply containing leaked `<tool_call>` markup leaves the buffer untouched and routes to the prose fallback
- two concurrent inline requests in different parts of one file: both diffs render, each `g2` accepts the right one, accepting the first does not misplace the second
- delete the anchored range mid-flight: request drops with a notification, no stray edit
- close a buffer with a diff pending: original lines are restored, not left half-applied
- `{` and `}` still perform their normal motions while a diff is pending
- connection lifecycle: nothing spawned at startup; overflow appears only under genuine concurrency and is gone ~60s later (`ps`); the primary is gone after 15 min; next request respawns transparently
- pool: fire 3 concurrent claude inline requests, confirm 3 connections, no cross-talk, and that a 4th queues rather than spawning
- kill an agent process mid-prompt: only its own request fails, the others complete
- **write refusal**: point `<leader>ci` at a scratch file and instruct it to modify the file directly; confirm the file is unchanged. Repeat for `<leader>cI`, including a shell-redirect instruction
- failure paths: ollama cloud 401 and 429, relay non-zero exit, relay `-T` timeout — each surfaces as a notification and clears its virtual text
- chat: a new chat on each provider comes up with the preset model/effort/mode already applied (confirm in the `gd` debug window)
- chat list: a session started in a terminal `claude` in this repo appears and restores with its history, including when nvim is opened from a subdirectory
- status panel: change effort on a live claude chat, confirm via the debug window that `thought_level` changed on the session

## Open items

- **Revisit opencode inline transport** — see the note under *Inline*. The next concrete experiment is named there.
- ~~Add the `claude-agent-acp` install guard~~ — resolved: `claude/install.sh` now guards it, plus an `opencode` presence check.
- ~~Where do the capability probes live?~~ — resolved: consolidated into `claude/.local/scripts/acp-capability-probe`, step 7 of *Build order*, with `tests/fixtures/` holding the recorded replies the parser is tested against.
- ~~Confirm that claude's `dontAsk` mode actually refuses writes~~ — resolved: it denies `Edit` and mutating shell commands while leaving reads working, verified against bytes on disk. `<leader>cI` ships.
- ~~Whether inline should expose claude's `agent` option~~ — resolved: no. Agent selection stays chat-only. The subagent definitions are written for autonomous multi-step work (`implementer`'s own description mandates a "Pre-pass: Grep target symbol across codebase"), which pushes toward the tool-seeking and prose that inline exists to avoid.
- ~~ollama cloud free-tier list~~ — resolved: `gpt-oss:20b`, `gpt-oss:120b`, `gemma4:31b`, `nemotron-3-super` confirmed; `ollama-cloud/qwen3.5:397b` needs a paid subscription and has been removed from `free_models` in `opencode-models.json`.
- ~~Whether to surface opencode's `mode` for inline~~ — moot: the relay transport has no ACP session.
