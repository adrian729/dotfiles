# Implementation details

## Why we rebuilt from scratch

The old integration had three fundamental problems. First, inline edits ran on local ollama and took up to two minutes. Second, the model decided where its own output landed — it could route an edit into a chat, into a new buffer, or nuke a whole file. Third, every provider had a different, ad-hoc switching UX (ollama had `vim.g.ollama_inline_model` and `toggle_ollama_think`, claude and opencode had nothing, and chat was separate again).

The rebuild replaced this with a single idea: **nvim owns placement; the model only supplies code.** All four transports share the same prompt contract, the same parsing layer, and the same diff UI. Providers and their options are defined once in `providers.lua` and read by inline, chat and the status panel — which is what makes the UX shared instead of reimplemented per surface.

The old integration was deleted entirely (step 00) rather than migrated feature by feature. Keeping both alive would have meant every step reasoning about two implementations bound to the same keys.

## Module layout and responsibilities

```
lua/ai/
  providers.lua       single source of truth: providers, options, defaults, selection, model lists
  acp_pool.lua        lazy ACP connections, overflow spawning, idle reaping, safety verification
  debug.lua           :AiPoolStatus and :AiDebugSend smoke harness
  inline/
    init.lua          prompt, placement, extmark anchoring, diff, accept/reject, concurrency, cancel
    parse.lua         fence stripping, prose and tool-call-leak detection
    http.lua          ollama local + cloud transports (curl over CodeCompanion's HTTP client)
    acp.lua           claude and opencode over ACP — ci/cI differ by prompt only
    relay.lua         opencode via the opencode-llm script — ci only, guaranteed tool-free
    list.lua          live float: every request in flight and every diff still to settle
  chat.lua            new chat with preset options, toggle, close-all, adapter resolution
  chat_list.lua       Telescope picker: live chats + resumable sessions from outside nvim
  status.lua          interactive option panel: reads providers.lua schema, applies to live sessions
  ui.lua              shared: in-flight range marking, prose-float message window, list rendering
```

`lua/plugins/codecompanion.lua` is kept to a lazy spec, adapter definitions, keymaps, and the `setup()` call. No logic lives there — everything is in the `ai/` modules.

CodeCompanion's ACP **client** (`acp/init.lua`, `acp/prompt_builder.lua`, etc.) is used directly — `Connection.new`, `connect_and_authenticate`, `session_prompt`, `on_message_chunk`, `on_complete`, `on_error`. These are all public and chat-agnostic. The built-in inline (`interactions/inline`) is not used at all; it hard-gates on `self.adapter.type ~= "http"`, so it cannot reach ACP transports.

## Provider architecture

`providers.lua` (`lua/ai/providers.lua`) is the runtime form of the provider schema. It defines:

- **Which providers exist** — `ollama`, `claude`, `opencode`
- **What options each carries** — per scope (inline/chat), with labels, categories (for ACP session config mapping), value lists, and dynamic model resolvers
- **What is currently selected** — stored per scope (`inline` and `chat`), with per-provider option tables
- **What each transport can reach** — `M.transports` is the canonical table from the measurements in `_codecompanion/findings.md`: HTTP and relay can touch nothing; ACP can read any file the user can but writes are denied

Defaults are free-first per `AGENTS.md`:
- Inline: ollama cloud `gpt-oss:120b` — ~4s, free, no local RAM
- Chat: claude `opus`, effort `xhigh`, mode `acceptEdits`

Model lists resolve dynamically and are cached per nvim session:
- Ollama local: `curl localhost:11434/api/tags`
- Ollama cloud: `curl https://ollama.com/api/tags` with `OLLAMA_API_KEY`
- OpenCode: parsed from `~/.local/config/opencode-models.json` (same file `opencode-llm` reads), falling back through `$XDG_CONFIG_HOME/opencode/` and `~/.config/opencode/`
- Claude: the static list matches what the live ACP session offers; the status panel re-resolves from the connection

The `auto` sentinel for opencode's model means "let opencode-llm walk its free-tier fallback list" — meaningful on the relay, but on an ACP session it resolves to the head of that list so it never lands on opencode's ambient default (currently the paid-tier-adjacent `big-pickle`).

## Connection pool

`acp_pool.lua` manages ACP connections for inline requests. Chat connections are separate — a shared connection would have the session-loading branch (`_loading_session and _on_session_update`) swallow inline `session/update` messages, silently dropping every inline reply.

Key properties:

- **Lazy**: nothing spawns at nvim startup. First use of a provider spawns one warm primary connection (~1.2s claude, ~0.8s opencode)
- **Overflow**: a second concurrent request on the same provider spawns its own connection, capped at 3 per provider. Beyond that, requests queue FIFO. Marginal cost is ~132 MB per claude process, ~536 MB per opencode process
- **Idle reaping**: overflow connections after ~60s idle, the primary after 15 minutes. Re-spawning is transparent on next use
- **All setup runs in coroutines**: `send_rpc_request` busy-waits with `vim.wait` outside a coroutine, which would freeze the editor for up to 90s
- **Per-request watchdog**: armed before the connection exists (a wedged agent can accept `initialize` and never answer `session/new`), re-armed when the prompt goes on the wire so queueing doesn't eat the reply's budget
- **Safety-critical session options are verified, not just requested**: `acp_defaults.apply` skips options the live session does not offer with nothing louder than a `log:warn`. On claude, that leaves the session in its default write-capable mode. The pool reads the values back off the live connection and refuses it if they did not take

The pool overrides `handle_fs_write_file_request` to refuse on every inline ACP connection. This path is never exercised by either agent today (both go directly to disk with their own tools), but it removes a latent whole-buffer clobber: the plugin's handler does `nvim_buf_set_lines(bufnr, 0, -1, …)` followed by `silent update!`, replacing the entire buffer and force-saving it. The override costs one function; pool init asserts the method exists so a future upstream rename silently stopping the override would fail loudly.

**Concurrency design**: ACP the protocol multiplexes sessions over one process, but CodeCompanion's client cannot do that — `Connection` holds `session_id` as a scalar and `_active_prompt` as a single slot, and `handle_incoming_request_or_notification` drops every message whose `sessionId` is not the active one. Multiplexing was evaluated and rejected: it requires patching three internal methods, managing `_active_prompt` and `session_id` by hand around every send, and relying on ordering assumptions in `handle_rpc_message` that could silently break on an upstream change. Concurrent inline therefore means concurrent connections.

**Cancellation**: `PromptBuilder:cancel()` clears `_active_prompt` synchronously without waiting for the agent, and the client's message router has no turn correlation — the cancelled turn's trailing chunks land in whichever request holds `_active_prompt` next, and reach the buffer as a diff. So a cancelled connection is dropped, not returned to the pool. The respawn (~1.2s) is cheaper than the corruption.

**Timed-out queued requests**: a request that resolves (timeout or cancel) while still queued must stay out of the queue. When it later gets a connection from `pump`, the completion path returns early because the request already resolved — and never releases the connection. Three such events exhaust the cap for the rest of the session. The waiter checks a resolved flag at the top and hands the connection straight back.

**Completion callbacks are deferred** with `vim.schedule`: `handle_done` clears `_active_prompt` *after* calling the completion handler. A callback that starts the next prompt inline within that stack has its new prompt nulled out.

**Process death** is hooked through the adapter's `handlers.on_exit`, set on the per-spawn resolved adapter (deepcopy preserves function references). The exit must be flagged synchronously inside the hook — `handle_process_exit` calls `on_exit` before marking the active prompt as cancelled, so without the flag the completion path reports a plain cancel and hides the crash.

**Teardown**: `Connection:disconnect()` throws on an already-dead handle; the reaper `pcall`s it and clears our state regardless.

## Inline transports

Four transports back the same prompt contract. Which one is used depends on the selected provider and whether the keymap was `ci` (shallow) or `cI` (deep, may read the repo):

| Provider | `ci` transport | `cI` transport |
|---|---|---|
| ollama | HTTP (curl) | n/a — refused with a message to switch provider |
| claude | ACP | ACP (same adapter, different prompt) |
| opencode | relay (`opencode-llm`) | ACP |

**HTTP (`inline/http.lua`)**: plain curl through CodeCompanion's HTTP client. Ollama cloud supports streaming, local does as well. The cloud endpoint is `https://ollama.com/api/chat` with `OLLAMA_API_KEY` as a bearer token. Local is `http://localhost:11434`. The `num_ctx = 16384` default is explicitly set — ollama's own default is small enough to silently truncate a real refactor. `keep_alive = "30m"` keeps the local model warm between calls.

The HTTP client has a double-callback bug on 4xx: it invokes the callback once with the error body as though it were a reply, then again with an error table. The transport checks `data.status >= 400` before handing anything to the adapter's parser.

**Relay (`inline/relay.lua`)**: shells out to `opencode-llm`, which runs a free-tier cloud model with no tools in a neutral cwd not on this repo. Guaranteed tool-free by construction — the model cannot read files, cannot write, and cannot run commands. The relay is only available for `ci` because `cI` needs the ability to read the repo, which the relay structurally cannot provide. Latency is ~9s for a small edit.

**ACP (`inline/acp.lua`)**: claude and opencode over ACP sessions from the connection pool. `ci` and `cI` differ only in prompt text — same adapter, same pool, same mode. `ci` gets "You have no tools. Work only from the text below." `cI` gets "You may read files in this repository to learn its conventions before answering. Do not modify any file: the editor applies your output, not you."

The prompt is self-contained for `ci`: the selection, 40 lines of surrounding context in `<before>`/`<after>` tags, the file path and filetype, and LSP diagnostics in the range. For `cI`, the model can read files through its own tools — our prompt steers it toward reading for conventions rather than for content.

Claude sessions run under `mode = "dontAsk"`, which denies mutating tools including shell redirects. OpenCode sessions run under `OPENCODE_PERMISSION` denying `edit`/`write`/`patch`/`bash` while allowing `read`/`grep`/`glob`/`list`. Denying everything backfires: the model still attempts a tool, nothing parses the attempt, and raw `<tool_call>` markup leaks into the reply as text. Allowing reads removes the leak entirely.

The `fs` capability is advertised as `false` for hygiene but is irrelevant — neither agent ever sends `fs/read_text_file` or `fs/write_text_file`; both go to disk with their own tools. The real write defence is the session mode or permission set.

## Contract and placement

The prompt contract is plain text for all four transports — no JSON envelope, no structured output schema. This is deliberate:

> You are an inline code editor inside Neovim. The editor decides where your output goes; you only supply code. Return ONLY the replacement text for the selected region. Reproduce every line you are not changing exactly as given. Do not add commentary.

An earlier revision tried a `{"code":"…"}` JSON envelope for HTTP and relay. It failed decisively: the same ollama cloud model with the same selection returned *the whole enclosing function* under the envelope — the `<before>` and `<after>` context folded back in — while the plain contract returned exactly the selected lines. The envelope reframes the task as "emit the code" and the model stops honouring the region boundary. Worse, brace-matching to find the closing `}` counts braces inside the JSON string, so any fragment with unbalanced braces — `if (x) {\n  go()\n}` — never closes, the decode is skipped, and the raw JSON falls through to the code path and into the buffer.

**Range capture**: on `ci`/`cI`, the current visual selection is captured via `'<` and `'>` marks. With no selection, an empty range at the cursor line means "insert here". The range is anchored with extmarks, not with line numbers. The built-in snapshots whole-buffer line numbers instead, which is exactly why two of its requests corrupt each other — an edit from a earlier-accepted diff shifts the numbers of a later one.

The extmarks use two anchors whose gravities both point **inwards** (start: `right_gravity = true`, finish: `right_gravity = false`), so the pair spans the lines the user picked and refuses to grow past them. A third `guard` mark spanning the full range with `invalidate = true` detects when the range has been deleted — collapsing start onto finish is not a reliable test on its own, since a user who deletes the range and types a replacement leaves the pair spanning unrelated text.

The outward-facing pair was tried first and is wrong, measured on a `--clean` nvim: a mark at `(1,0)` with left gravity moves to `(0,0)` when the line above it is replaced, and one at `(4,0)` with right gravity moves to `(5,0)` when the line below it is. Either way the range quietly grows over a line the user edited while the request was in flight, and the reply overwrites that edit when it lands. Inward gravities also fix the insertion-point case, where the outward pair let a line typed at the cursor row fall *inside* the range and be replaced by the answer. Note the diff marks in `show_diff` keep the opposite gravities on purpose — those have to grow to cover the text the diff inserts into them.

**One edit per region**: a request is refused when any of its lines is already held by a request in flight or by a diff still waiting on a decision (`held_by`). Both prompts would be built from the same text, so whichever answer landed second would describe a rewrite of code the other had already replaced. The check runs before the prompt float opens — being told the lines are taken is no use once an instruction has been typed — and again at submit, since the float stays open for as long as it takes to type. An insertion point owns no lines but does sit on one, and is treated as covering the row it is on.

**Protecting a range in flight**: while a request with a real selection is running, an edit landing on its lines is put straight back (`enforce_guards`). The prompt was built from those exact lines, so an edit on top of one means an answer that silently discards whatever the user typed the moment they accept it. `nvim_buf_attach`'s `on_bytes` schedules the check — it holds textlock, so the buffer cannot be written from inside it — and the comparison is by content against a snapshot rather than by where the edit landed, because the marks have already moved by the time we look and a range that merely shifted is not a range that was touched. The restore is `undojoin`ed onto the edit it undoes, so the pair is one undo step; left as two, a `u` would put the blocked edit back and the guard would revert it again. Deleting the whole range invalidates the guard mark, so the lines go back at the start mark — which survives the deletion, collapsed onto the seam — and the request is re-anchored, since a range that resolves to nothing for the rest of its life would have its answer dropped on arrival. `InsertEnter` on a held line is refused outright, which is cheaper and less startling than letting the text change and reverting it; the content check remains the backstop for operators that change text without entering insert. An insertion point is not protected: it holds no lines to put back, and its anchor rides along with the edits around it.

Only in-flight requests are protected, not pending diffs. The diff UI writes its own rendering into the buffer, so a content guard there would be fighting the plugin rather than the user.

**The exclusive-end-on-last-line case**: an exclusive end row equal to the buffer's line count has no line to sit on, so the mark is clamped onto the last line's end column. A flag (`ends_at_eof`) is stored alongside the mark to distinguish that from a mark genuinely at the start of the last line. Without it, a selection running to the end of the buffer silently loses its final line — and the reply's own last line is appended as a duplicate. The column alone cannot tell: when the last line is empty, the end of the line and the start of it are the same position.

## Parse and diff

`parse.lua` extracts a fenced code block when one is present. If the reply is not fenced, it checks whether it is prose:

- Claude often wraps code in ` ```lua ` but sometimes returns bare code
- The ollama models return bare code
- OpenCode has been observed doing both
- With tools enabled, claude also prefixes prose before the fence

An unfenced reply is treated as **code by default**. The converse — reject the reply unless it looks like code — was measured and fails badly: most lines of most languages match no code pattern (`end`, `fi`, `SELECT name`, `FROM users`, `set -eu`, `name: build`, a bare identifier). In a Markdown, text or `gitcommit` buffer, the correct replacement *is* a sentence. A heuristics-based prose detector misfiled 9 of 20 replies as prose, 4 of those being live ollama cloud output.

Prose needs **positive** evidence — leaked tool-call markup, an explicit refusal opener, or an all-sentences reply that reuses no line of the selection in a buffer whose filetype is code. The original selection lines are kept through the request specifically for this check: a reply that echoes them is an edit, however little it looks like code in isolation.

**Diff rendering**: `from_lines` and `to_lines` are constructed as whole-buffer snapshots — the request'd region is replaced in `from_lines` with the reply, and `show_diff` computes the hunks. The built-in `apply_inline` addresses hunks by absolute buffer row, so passing just the region would apply them at the top of the file.

`show_diff` is called with `skip_default_keymaps = true` and the `on_accept`/`on_reject` callbacks are supplied directly. This gives us control over `g2`/`g3`, which is what makes concurrent diffs possible. The built-in shares one `g1`/`g2`/`g3` across all diffs, and `resolve_diff` clears all of them on any resolution — resolving one diff unbinds a second pending diff's keys. Ours re-binds after each resolution, and dispatches per-cursor-position through `diff_under_cursor` rather than per-diff-window.

**A diff's extent comes from the reply's length, not from its end mark** (`diff_region`). The end mark cannot be trusted: DiffUI renders a deletion as *real* lines and removes them again in `clear()`, and a right-gravity mark grows over them without ever shrinking back — and a neighbouring diff landing on the row after this one pushes it too. Measured: three one-line diffs on rows 0, 1 and 3 resolved to `0..2`, `1..2` and `3..5` while each owned exactly one row. Rejecting them all then ate a line, order-dependently. The start mark has none of that trouble (left-facing, at the top of the region, so only whole rows moving above it shift it, and those shift its content with it), so the region is `start .. start + #replacement` — which is why the reply's lines are kept on the diff as `replacement`. `diff_under_cursor` and the inline list's location both read the same function, so a diff's row test can no longer stray onto its neighbour's rows.

**Rejection is batched and verified.** Every rejection in a tick is queued and flushed together (`queue_restore`): all regions are measured before any is written, so no region is read after another has moved it, and they are applied bottom-up so a write cannot shift a region still to come. Measuring is left to the flush rather than done at rejection time because `clear()` deletes DiffUI's spacer line after the callback, and rows taken before that are one out. Each region is compared against the diff's `replacement` before being overwritten — that catches a derivation gone wrong, and also the user having edited the diff themselves, where the original going back would silently destroy their work. On a mismatch the reply is left in place with a warning naming the file and line; that failure is visible and `g3` still works once they are done.

**Rejection restores only the target diff's region**, not the whole buffer. The built-in's reject is `nvim_buf_set_lines(bufnr, 0, -1, original)` — a whole-buffer restore, which is precisely why two concurrent requests corrupt each other. Ours resolves the extmarks to get the current region, then restores only those lines. The restore is deferred with `vim.schedule`: when a hunk starts at line 1, DiffUI inserts a real empty spacer line at row 0 and deletes it in `clear()`, which runs after the reject callback. Restoring first makes that deletion land on a line of ours and silently swallow it.

**Auto-reject on buffer close**: under `skip_default_keymaps`, DiffUI's auto-reject on premature close is disabled. Our `watch_buffer` autocmd group restores `from_lines` on `BufDelete`/`BufUnload`, and on `WinClosed` — but only when no other window still shows the buffer. `WinClosed` with `buffer = N` fires on "a window showing this buffer closed", not "the buffer went away"; without counting remaining windows with `win_findbuf`, closing one split of two throws away a finished, unaccepted edit.

**The empty-buffer case**: DiffUI's `create_diff_display` writes the merged old-and-new view straight into an empty buffer and `apply_inline` then applies hunks on top — so the reply lands twice. Since there is nothing to diff against in an empty buffer, our code detects this and writes the reply directly, leaving `u` as the way back.

**DiffUI hijacking the current window**: when the target buffer is off screen, DiffUI falls back to `nvim_get_current_win()` and calls `nvim_win_set_buf` on it. Since requests run for seconds and moving on is normal, we check `bufwinid(bufnr)` before calling `show_diff`. If the buffer is not on any window, the reply is dropped with a notification rather than yanking whatever the user went to read.

## Chat management

`chat.lua` wraps CodeCompanion's `Chat.new` with our provider system:

- **`new()`**: resolves the current chat provider's adapter, builds `session_config_options` from stored opts (mapping option keys to ACP categories via `providers.lua`), resolves the opencode `auto` sentinel to a real model, strips inline defences (OPENCODE_PERMISSION) from the resolved adapter so the chat gets full tool access, and passes it to `Chat.new`
- **`toggle()`**: delegates to the plugin's own toggle by calling `:CodeCompanionChat Toggle` — but only when a real chat already exists. Without this guard, the plugin's toggle creates a brand-new chat with `adapter = nil` when there is none, bypassing all provider/model/effort/mode setup
- **`close_all()`**: snapshot `_G.codecompanion_buffers` before iterating, since `Chat:close()` mutates it via `table.remove` and `ipairs` would skip elements as later entries shift down. Routes through `Chat:close()` to disconnect the ACP connection and keep bookkeeping in sync — a raw `buf_delete` would leak the subprocess
- **`open_with_context()`**: the prose-float upgrade. When inline declines an edit, the float's `<CR>` passes the instruction, selection and model reply through to `open_with_context`, which creates a chat pre-loaded with those messages. The user continues the conversation where inline left off

Claude's `agent` option has `category = nil` in the ACP schema, so it cannot be set via `session_config_options` and must be applied after the session exists via `conn:set_config_option`. `chat.lua` stashes the agent name per-buffer and applies it on the first `CodeCompanionChatSubmitted` event, which fires after the session is live.

A "thinking…" spinner is shown during chat requests via autocmds on `CodeCompanionChatSubmitted` / `CodeCompanionRequestFinished`. The spinner skips the case where `ChatSubmitted` fires but `current_request` is nil — an ACP submit that fails before a prompt exists still fires the event, but `RequestFinished` never comes, so a spinner started there would never stop.

## Status panel

`status.lua` generates its rows from `providers.lua`'s schema. A new provider option appears here with no edit to the panel code.

For each scope (inline, chat), it renders:
- A **provider row** with the current provider and, for inline, a reach marker: `(tool-free)` for HTTP/relay, `(can-read-repo)` for ACP
- **Option rows** for every option that provider+scope carries

Values are resolved in priority order: live session `currentValue` first (read from the ACP connection's `get_config_options()` for the focused chat's session), then the stored default from `providers.lua`.

**Enter** on a row starts editing; **h/l** cycles values; **Enter** again commits or **Esc/q** cancels. A commit writes the value to `providers.lua`'s stored state and, for chat scope, to the live ACP session via `conn:set_config_option`. Inline provider/model changes also drain the pool so the next request picks up the new config.

The panel rebuilds its rows on `BufEnter` (refocus) so it shows the current state even if something changed outside the panel. While a row is being edited, this refresh is skipped. Rows carry `built_for_provider` to detect a stale commit: if the focused chat's provider changed while the panel was open and a row built under the old provider is committed, the panel warns and refuses rather than silently writing to the wrong session.

## Chat list

`chat_list.lua` uses Telescope to render two groups:

1. **Live chats** — every buffer in `_G.codecompanion_buffers`, sorted with the title. `<CR>` focuses via `chat.ui:open()`
2. **Resumable sessions** — fetched via `session/list` from an ACP connection. The list is filtered to sessions whose `cwd` starts with the current git root, so sessions don't vanish when nvim is opened in a subdirectory. Sorted by `updatedAt`. `<CR>` restores the session into a new chat buffer with full history rendered

The session connection prefers an existing live chat's connection to avoid spawning a process. If none is available, it spawns claude first (cheaper, faster), then falls back to opencode. A connection spawned solely for listing is disconnected afterward.

Live chats that share a session with a resumable entry are excluded from the resumable section — a chat you can see is not also "resumable". `clear_cache()` drops the cached session list so the next open re-queries; it is called after session restoration since the restored session is now a live chat.

## Write safety

Three independent layers keep inline from writing to disk, listed from actual to insurance:

1. **Agent permission mode (actual)**: claude sessions run under `dontAsk`, which denies mutating tools including shell redirects. Verified on bytes on disk: three configurations tested (fs write true + dontAsk, fs write false + dontAsk, explicit `echo >> file` command), and all three left the file unmodified. DontAsk is not a blanket tool block — a read-only shell command succeeds — but it classifies per invocation and denies the mutating ones. OpenCode sessions run under `OPENCODE_PERMISSION` denying `edit`/`write`/`patch`/`bash` while allowing reads; denying-everything leaks tool-call markup as message text.

2. **Session option verification (guard)**: `acp_defaults.apply` skips options the live session does not offer with only a `log:warn`. If a version bump renames the option or changes its casing, the session stays in the agent's default mode — which on claude means write-capable tools. The pool reads `currentValue` back and refuses the connection when the option did not stick. This fails closed.

3. **Client-side write guard (insurance)**: `handle_fs_write_file_request` is overridden to refuse on every inline ACP connection. Neither agent uses that path today — both write directly to disk with their own tools — but the override removes a latent whole-buffer clobber for one function. Pool init asserts the method exists so a future upstream rename silently stopping the override fails loudly.

## Key design decisions

**Why opencode's inline transport splits**: `ci` uses the relay because it is guaranteed tool-free and has no process overhead. `cI` uses ACP because the relay structurally cannot read the repo. This split means `cI` on opencode pays ~536 MB of RSS for the ACP process, but that is why the idle reaper exists — the process doesn't linger.

**Why concurrency means processes, not sessions**: CodeCompanion's ACP client multiplexing was evaluated and rejected. It requires patching `handle_incoming_request_or_notification`, `store_rpc_response`, managing `_active_prompt` and `session_id` by hand around every send, and relying on ordering assumptions in the `stopReason` check that could silently break. It also leaves `_config_options` connection-global, so per-request model or mode selection would read the wrong option set. Concurrent connections are more expensive but correct.

**Why the inline prompt forbids JSON envelopes**: measured on the same selection, the envelope caused the model to return the whole enclosing function. The plain contract was byte-perfect. The envelope also cannot be extracted reliably from code fragments whose braces do not balance.

**Why the pool verifies safety options instead of trusting the harness**: `acp_defaults.apply` is chat-agnostic despite its path and silently skips anything the session does not offer. On claude, this is the entire write defence. A version bump mid-investigation (0.55 → 0.59) gained the `configOptions` mechanism that makes this possible; another one could rename it. The verify step catches that.

**Why cancelled connections are dropped, not released**: `PromptBuilder:cancel()` clears `_active_prompt` synchronously and the client has no turn correlation. The cancelled turn's trailing chunks land in the next request's `_active_prompt` and reach the buffer as a diff. Paying a ~1.2s respawn is cheaper than the corruption.

**Why the built-in inline's reject restores the whole buffer**: `interactions/inline/init.lua:817-821` does `nvim_buf_set_lines(bufnr, 0, -1, original)`. This is the precise reason two concurrent built-in requests corrupt each other. Our rejection restores only the target diff's extmark-tracked region. The restore is `vim.schedule`d so DiffUI's own spacer-line deletion in `clear()` does not swallow ours.

**Why `<leader>cI` is prompt-deep only on claude**: same adapter, same pool, same mode, same capabilities. The behavioural gap — ~5s and no tools versus ~27s and repo reads — comes entirely from the prompt wording. It is a speed-and-intent choice, not a security boundary. On opencode the two are genuinely different transports (relay vs ACP), and on ollama `cI` does not exist. So the pair means something different on each provider, which is a UX wart worth watching.

**Why an in-flight request is marked with a virtual line and a tint, not end-of-line text**: end-of-line text on the first row says nothing about how far down the request reaches, so a multiline selection was indistinguishable from a single-line one — and the extent is exactly what decides whether an edit of yours is about to be overwritten. The label moves to a line of its own above the range, indented to the code it belongs to, and the range itself carries an `AiInlineRange` background. The line count is spelled out in the label as well as shown in colour, because a tint is easy to miss and invisible on the row the cursor sits on. `ui.progress` keeps the end-of-line form for callers that pass a single row rather than a range — the chat spinner, where there is no extent to show and pushing the buffer down by a line would be noise.

**Why the debug harness (`:AiPoolStatus` / `:AiDebugSend`) stays in the final build**: it is the seam where a transport problem is distinguishable from a parsing or placement problem. `:AiDebugSend` does no parsing, no placement and no buffer mutation — it sends a raw prompt through the pool and shows the reply in a scratch buffer. When a later change misbehaves, this is the first thing to reach for.
