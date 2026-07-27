# CodeCompanion rebuild — verified findings

Evidence base for the step files in this directory. Nothing here is a decision; every claim is either a measurement taken on this machine or a citation into the installed plugin source.

Two sources. Live probes of `claude-agent-acp` 0.59.0, `opencode acp` 1.18.0, the ollama cloud API and the repo's own `opencode-llm` relay — facts marked *measured* were timed here, not assumed. And an audit of the installed plugin at commit `d34edce`, checking that CodeCompanion's ACP **client** can do what the protocol allows and that its stock adapters behave the way the probes did. Several did not. Citations of the form `acp/init.lua:685` are relative to `~/.local/share/nvim/lazy/codecompanion.nvim/lua/codecompanion/`.

**This file is perishable.** Agent versions move and ambient models drift — `claude-agent-acp` went 0.55 → 0.59 mid-investigation and gained the whole `configOptions` mechanism the status panel depends on, and opencode's tool-use behaviour changed between two probe runs days apart. Step 07 builds the script that regenerates the tables here. Treat any number as stale until it has re-run.

## Inline cannot use ACP adapters (built-in)

`interactions/inline/init.lua:208` hard-gates on `self.adapter.type ~= "http"`, same gate in `interactions/cmd.lua:29`, and `doc/configuration/inline.md` states it. Inline goes through `codecompanion.http` (curl); ACP is a stdio JSON-RPC subprocess. Not a config problem.

**But every API needed to build ACP inline ourselves is public and chat-agnostic:**

- `require("codecompanion.acp").new({ adapter = ... })` → `:connect_and_authenticate()` → `:session_prompt(messages)` returns a builder with `:on_message_chunk()`, `:on_tool_call()`, `:on_permission_request()`, `:on_complete()`, `:on_error()`, `:with_options({ bufnr, interaction })`, `:send()` (pattern from `interactions/chat/acp/handler.lua:207`).
- `require("codecompanion.helpers").show_diff({ bufnr, from_lines, to_lines, inline = true, banner, keymaps = { on_accept, on_reject }, skip_default_keymaps = true })` renders the same inline diff the built-in uses. `skip_default_keymaps` is what lets us own `g2`/`g3` for concurrency.

`show_diff` **applies the change and never reverts it.** An earlier draft of this file had that backwards. With `inline = true`, `DiffUI:apply_inline` (`diff/ui.lua:293`) writes the `to_lines` into the buffer hunk by hunk and renders the deletions as virtual lines. What it does *not* have is an accept or reject method — `diff/keymaps.lua:67-85` dispatches to the `on_accept`/`on_reject` callbacks *we* supply. So accept is a no-op on the text, and **undoing is ours to write**, exactly as the built-in does at `interactions/inline/init.lua:817-821`.

Three consequences, all of which bit:

- `from_lines`/`to_lines` must be **whole-buffer** snapshots, because `apply_inline` addresses hunks by absolute buffer row. Passing just the region applies it at the top of the file.
- The built-in's reject is `nvim_buf_set_lines(bufnr, 0, -1, original)` — a whole-buffer restore, which is precisely why two of its concurrent requests corrupt each other. Ours restores only the rejected diff's own extmark-tracked region.
- When a hunk starts at line 1, `apply_inline` inserts a **real empty spacer line at row 0** and removes it again in `clear()`, which `resolve_diff` runs *after* the reject callback. Restoring the region before that deletion makes it land on a line of ours and silently swallow it. Defer the restore with `vim.schedule`.

## The `fs` capability is inert for both agents (measured)

The stock claude adapter advertises full filesystem access:

```lua
-- adapters/acp/claude_code.lua:31-36
parameters = {
  protocolVersion = 1,
  clientCapabilities = {
    fs = { readTextFile = true, writeTextFile = true },
  },
```

Withholding it changes nothing, and advertising it changes nothing either. Probed across both agents — capability granted and withheld, targets inside and outside cwd, and with writes permitted — **neither `claude-agent-acp` nor `opencode acp` ever sent `fs/read_text_file` or `fs/write_text_file`:**

| agent | reads via | writes via | client `fs/*` calls |
|---|---|---|---|
| `claude-agent-acp` 0.59.0 | own `Read File` tool | own `Edit` tool, straight to disk | **none, in any configuration probed** |
| `opencode acp` 1.18.0 | own `read`/`grep`/`glob` | own `edit` tool, straight to disk | **none, in any configuration probed** |

The capability advertises a service *we* offer. Neither agent wants it; both go to the filesystem themselves. Two consequences follow, and they point in opposite directions from an earlier draft of this plan.

**Withholding the capability is not a constraint.** With `readTextFile = false`, claude read a file *outside* cwd and echoed its contents back, and no session mode prevents that:

| session mode | read outside cwd | contents echoed into the reply | permission requests |
|---|---|---|---|
| (unset) | yes | yes | 0 |
| `plan` | yes | yes | 0 |
| `dontAsk` | yes | yes | 0 |
| `default` | yes | yes | 0 |
| `acceptEdits` | yes | yes | 0 |

Every mode read the file and printed a sentinel token back. So **no claude configuration makes inline structurally read-free**: a claude inline request can read any file the user can and echo it into its reply, where inline would either insert it or show it in the prose float. `claude.env`, `ollama.env` and `~/.ssh` are all in reach. Accepted rather than solved — confining our own `handle_fs_read_text_file_request` achieves nothing when the agent never calls it.

**But the agent's own judgement pushes back, once a real system prompt frames the request.** Re-measured through the finished inline path rather than a bare protocol probe: asked to read a sentinel file outside the repo and reply with its contents, claude *declined both times*, naming it as an injection attempt — "asking me to read a file outside the repo and exfiltrate its contents as my 'code' output". So the capability is unrestricted while the behaviour is not. Do not soften the accepted-risk note on the strength of this: it is model judgement, it is version-dependent, and a request framed as a legitimate part of the edit would not trip it. What it does mean is that the earlier flat claim "a claude inline request will read anything and echo it" overstates what happens in practice.

**The client-side write hole is real but unexercised.** `handle_fs_write_file_request` (`acp/init.lua:771`) validates only `sessionId` and the param types, then calls `fs.write_text_file`, which **looks for an open buffer first** — and if the target is loaded it does `nvim_buf_set_lines(bufnr, 0, -1, …)` followed by `silent update!`, replacing the entire buffer and force-saving it to disk. `FileEdited` fires after the fact, and `DISPATCH` (`acp/init.lua:643`) has no capability gate, so any agent choosing this path would get that behaviour whatever we advertised. Neither of ours does. The per-connection override is therefore **cheap insurance against a future version or a third agent, not the thing keeping us safe** — it costs one function and removes a latent whole-buffer-clobber, so it stays, but nothing today exercises it. It works because `DISPATCH` invokes the handler as a method on `self`, so an instance-level override wins; it fails open if upstream ever inlines the write logic into `DISPATCH` the way it already has for `session/update`.

**What actually prevents writes is the session mode or permission set** — `dontAsk` for claude, an `OPENCODE_PERMISSION` deny set for opencode. Those govern the agents' *own* tools, which is the only path either one uses.

And the real predictor of tool use is the **prompt**, not the capability. The six-case spike saw no tool use because its prompts were self-contained, not because `fs` was off. Measured on opencode with tools fully available: a self-contained edit drew zero tools at 4.5s, while "match the error-handling pattern used elsewhere in this repository" drew `glob`+`grep` at 10.0s. Prompt steering is the same lever the relay exploits, and for the ACP transports it is the only one inline has.

`PromptBuilder:on_write_text_file` is **not** a veto point despite the name: it fires after the bytes have landed and `send_result` has gone out, and only when `_active_prompt` is set — which the plugin's own comment notes need not be the case. It is a notification. Do not wire it as protection.

## Transport reach (measured)

Canonical table — steps 03 and 05 cite this rather than restating it. Whether inline can touch the filesystem is a property of the **transport**, not of which keymap was pressed.

| Provider / transport | can read the filesystem | can write | what stops writes |
|---|---|---|---|
| ollama local or cloud (HTTP) | **no** | **no** | structural — no tool plumbing exists |
| opencode via the `opencode-llm` relay | **no** | **no** | structural — deny-all agent in a neutral cwd |
| claude over ACP | yes, anywhere the user can | no | session mode `dontAsk` |
| opencode over ACP | yes, anywhere the user can | no | `OPENCODE_PERMISSION` denying `edit`/`write`/`patch`/`bash` |

## Spike result: the text-only contract holds

Six cases per agent — long-selection rename, conversational question, deliberate tool temptation, cursor-insert, impossible request, no-op — plus the same rename against the cloud models. Every ACP row was probed with `fs` explicitly **off** which, per the finding above, steers the agent rather than constraining it.

| Backend | 57-line rename | verbatim? | fences | tools used |
|---|---|---|---|---|
| ollama cloud `gpt-oss:20b` | **2.22s** | yes | no | n/a |
| ollama cloud `gpt-oss:120b` | **3.93s** | yes | no | n/a |
| claude ACP (`fs` off) | **5.12s** | yes | ` ```lua ` | **none, in all 6 cases** |
| opencode ACP | 9.45s → 10.42s | yes | no → yes | see below, and drifted |
| opencode relay (`opencode-llm`) | ~9.3s (small edit) | yes | no | none, by construction |
| ollama local `qwen3-coder:30b` | ~119s (from log) | — | — | n/a |

**The opencode row has already drifted between probe runs.** The first pass saw it run `grep`/`read`/`glob`/`bash` and return bare code; a later pass on the same prompts saw no tools at all and fenced code, at comparable latency. Most likely its ambient default model changed. Treat every opencode number here as perishable.

Four behaviours the design has to accommodate:

1. **Claude returns prose when it shouldn't edit** — 3 of 6 cases. It explained the code when asked a question, and *refused* rather than guessing when asked to match a repo pattern with tools off. Correct behaviour, but prose must never be inserted into a buffer.
2. **Fence handling differs and is not stable.** Claude wraps in ` ```lua `, the ollama models return bare code, and opencode has been observed doing both. With tools enabled claude also prefixes prose before the fence. The parser must extract the fenced block when one is present, not trust the whole reply.
3. **opencode over ACP cannot be made cleanly tool-*free*, but it can be made write-free.** It ignored "do not use any tools", ran `grep`/`read`/`glob`/**`bash`** against the repo, and raised **zero** permission requests — so auto-denial never gets a say. Setting session mode to `plan` did not stop it. `OPENCODE_PERMISSION` does reach an ACP session, but denying everything backfires: the model still attempts a tool, nothing parses the attempt, and raw `<tool_call><function=grep>…` leaks into the message text where inline would insert it into the buffer. Denying only the *mutating* tools avoids the leak entirely.
4. **Neither agent asks permission for reads, so permission handling is not a safety mechanism.** With `fs` advertised, claude ran Terminal tools and raised zero permission requests too (27s, prose prefixed before the fenced code). Denying writes cannot rely on answering `session/request_permission` — nothing arrives to answer.

## A structured `{"code":…}` envelope makes placement worse, not better (measured)

Tried as a way to let the parser extract code without heuristics, on the HTTP and relay transports only. It fails, and the failure is not subtle. Same C selection, same instruction (`rename total to running_total`), ollama cloud `gpt-oss:120b`, one request each:

| Contract | What came back |
|---|---|
| plain (`Return ONLY the replacement text for the selected region`) | exactly the three selected lines, byte-perfect, unfenced |
| `{"code":"…"}` envelope | **the whole enclosing function** — the `<before>` and `<after>` context folded back in |

Asking for an envelope reframes the task as "emit the code" and the model stops honouring the region boundary, which is the one thing this design exists to control. On top of that the envelope cannot be extracted reliably: brace-matching to find the closing `}` counts braces inside the JSON string, so any fragment with unbalanced braces — `{"code":"if (x) {\n  go()\n"}`, i.e. most C-family fragments — never closes, the decode is skipped, and the raw JSON line falls through to the code path and into the buffer.

It is also the workaround this rebuild set out to delete: README → *The contract* names the ollama `format` JSON schema as one of two things the plain prompt replaces. One contract, all four transports.

## Prose detection: "doesn't look like code" is not evidence (measured)

The obvious heuristic — reject the reply when fewer than half its non-blank lines match a code pattern — misfiled **9 of 20** replies as prose, 4 of the 20 being live ollama cloud output. Most lines of most languages match no code pattern: `end`, `fi`, `SELECT name, email`, `FROM users`, `set -eu`, `name: build`, a bare identifier. Worse, in a Markdown, text or `gitcommit` buffer the *correct* replacement is a sentence, so the heuristic rejected every good reply in exactly the files where prose is the point.

The cost is asymmetric and the heuristic had it backwards. A reply wrongly treated as code costs one keystroke — it renders as a diff that must be accepted, and `g3` restores the buffer. A reply wrongly treated as prose costs the whole request: the edit does not happen, and the user pays the model's latency again. So an unfenced reply is code by default and prose needs positive evidence — leaked tool markup, an explicit refusal opener, or an all-sentences reply that reuses no line of the selection in a buffer whose filetype is code. Rule and corpus in `02-parse.md`.

## `dontAsk` refuses writes, including shell escapes (measured)

Whether claude's `dontAsk` mode genuinely refuses writes gated the whole repo-reading inline path. Tested three ways, with the verdict taken from the bytes on disk rather than from what the agent claimed:

| Configuration | Agent behaviour | File on disk |
|---|---|---|
| `fs` write **true** + `dontAsk` | ran `Terminal` (read-only `ls`/`cat`), `Read`, then `Edit` — Edit denied by the harness | **unmodified** |
| `fs` write **false** + `dontAsk` | `Read`, then `Edit` — denied | **unmodified** |
| `fs` write **false** + `dontAsk`, explicitly instructed to write via `echo … >> file` | Bash denied outright: *"Permission to use Bash has been denied because Claude Code is running in don't ask mode"* | **unmodified** |

Zero permission requests in all three.

The third row is the decisive one. In the first row a read-only Bash command *succeeded* under the same mode, so `dontAsk` is not a blanket tool block — it classifies per invocation and denies the mutating ones, shell redirects included. That makes claude inline **structurally** safe against writes rather than safe-by-model-restraint. It says nothing about reads, which no mode restricts at all.

Caveat: this enforcement lives in `claude-agent-acp`'s permission classifier, not in our client. It is version-dependent, which is why step 07's probe tracks it.

## opencode over ACP: three permission configurations (measured)

Same two prompts, `cwd` on this repo.

| `OPENCODE_PERMISSION` | repo-hungry prompt | self-contained prompt | repo modified |
|---|---|---|---|
| none — all tools allowed | 10.0s, `glob`+`grep`, clean fenced code | 4.5s, no tools, clean fenced code | no |
| the relay's full deny set | failed to `initialize` at all this run; leaked raw `<tool_call>` markup on an earlier one | — | no |
| reads allowed, `edit`/`write`/`patch`/`bash` denied | 40.0s, 14 tool calls, returned **prose** | 13.1s, `grep`+`read`, bare code | no |

The leak trigger is denying a tool the model reaches for. Allow reads and it disappears — no configuration with reads permitted produced markup. Each row is one sample against a drifting ambient model; treat the latencies as measured, not typical.

The unrestricted row is **not** an option despite being the fastest and cleanest: with tools open, opencode edited a file on disk with zero permission requests in the write-path probe. Denying mutation is not optional.

## Concurrency: one session per connection, so concurrency means processes

ACP the protocol multiplexes sessions over one process — measured: two prompts on **two** sessions of one process run genuinely in parallel (claude 2.73s + 4.11s of work in 4.11s wall; opencode 2.56s wall). Two prompts on **one** session cannot be attributed, since `session/update` carries only a `sessionId`.

CodeCompanion's client cannot do that multiplexing. `Connection` holds `session_id` as a scalar and `_active_prompt` as a single slot, `start_agent_process()` spawns a subprocess per `Connection`, and `handle_incoming_request_or_notification` (`acp/init.lua:685`) **drops every message whose `sessionId` isn't the active one** — notifications silently, requests with an `invalid sessionId` error.

Multiplexing anyway was evaluated and rejected. It requires overriding `handle_incoming_request_or_notification` and `store_rpc_response`, managing `_active_prompt` and `session_id` by hand around every send, and relying on the *ordering* of the `stopReason` check inside `handle_rpc_message:585` — which, if upstream reorders it, silently stops completions from ever firing. It also leaves `_config_options` connection-global (`acp/init.lua:821`), so per-request mode or model selection would read the wrong option set.

**So concurrent inline means concurrent connections.** Measured marginal cost, which gets no page-sharing benefit — each process costs full price, and the system-wide delta is worse than the RSS sum:

| Processes | RSS each | Cumulative system delta |
|---|---|---|
| 1 | 132.8 MB | 140 MiB |
| 2 | 131.8 MB | 354 MiB |
| 3 | 132.0 MB | 655 MiB |

This constraint applies to **both ACP transports** — claude, and opencode when `cI` runs on it. ollama cloud is plain HTTP with no sessions, and the opencode relay forks a subprocess per call, so those two are already unboundedly concurrent. Note opencode's idle RSS is ~536 MB against claude's ~133 MB, so an opencode overflow connection is four times the memory of a claude one; the cap matters more there.

## Process and session costs (measured)

| | claude-agent-acp | opencode acp |
|---|---|---|
| spawn → `initialize` | 0.13s | 0.56s |
| `session/new`, cold process | 1.31s | 0.20s |
| `session/new`, warm process | 0.95s | 0.00s |
| spawn + handshake + session, end to end | 1.12–1.26s | — |
| idle RSS | 133 MB | **536 MB** (667 MB after two prompts) |

Claude reported `cachedWriteTokens: 19151` on a session's first prompt — every new claude session loads the Claude Code system prompt plus this repo's `CLAUDE.md`/`AGENTS.md`. Sessions are cheap in time on a warm process, but not free in tokens, and a reused session accumulates every prior edit in its history.

## Provider capability matrix (probed)

| | claude-agent-acp 0.59.0 | opencode acp 1.18.0 | ollama local | ollama cloud |
|---|---|---|---|---|
| model | `default`/`sonnet`/`fable`/`opus`/`haiku` | 41 ids | 4 installed | free tier of the account key |
| effort | `thought_level`: default→max | — | — | — |
| fast mode | `model_config`: on/off | — | — | — |
| permission mode | auto/default/acceptEdits/plan/dontAsk/bypassPermissions | build/plan | — | — |
| tool restriction | `dontAsk` denies mutating tools incl. shell; **no mode restricts reads** | `OPENCODE_PERMISSION` per tool: denying reads leaks tool-call text, denying only mutation works | — | — |
| read confinement | none — any path, any mode, no prompt | none — any path, no prompt | n/a | n/a |
| client `fs/*` used | never | never | n/a | n/a |
| agent | all 45 local subagents | no `--agent` flag on `opencode acp` | — | — |
| thinking | — | — | `think` bool | ignored |
| structured output (`format`) | n/a | n/a | yes | **no** |
| sessions | list/resume/fork/delete/close | list/resume/fork/close | — | — |
| auth | `authMethods: []` → **no OAuth token needed** | shortcircuited in adapter | — | `OLLAMA_API_KEY`, already in env |

ollama cloud is reachable at `https://ollama.com/api/chat` with `Authorization: Bearer $OLLAMA_API_KEY`, same wire format as local — the stock `ollama` HTTP adapter works against it with only an `env.url` and header change. The **local** server cannot proxy cloud models (`Unauthorized`). Free-tier models confirmed reachable: `gpt-oss:20b`, `gpt-oss:120b`, `gemma4:31b`, `nemotron-3-super`.

## Session config options are settable declaratively

`interactions/chat/acp/defaults.lua:49` applies `adapter.defaults.session_config_options` keyed by **category** (`model`, `mode`, `thought_level`, `model_config`), resolving values by id *or* display name, case-insensitively, and accepting functions evaluated at call time (so they can read `vim.g`). Model is applied first because it changes which other options exist. `adapters/acp/init.lua:106-130` merges the option set into the resolved adapter, and `Chat.new{ adapter = … }` accepts the result.

Exception: claude's `agent` option has `category: null`, so it is unreachable that way — it must be set with `conn:set_config_option("agent", name)` after the session exists.

Note that `_apply_config_options` (`acp/init.lua:821`) does a wholesale `self._config_options = config_options`, connection-global. With one session per connection that is harmless, and it is what makes per-request model and mode selection possible.

## Session listing works and is cross-tool

`session/list` on claude returned 84 sessions with `sessionId`, `cwd`, `title`, `updatedAt` — including sessions started in the terminal, not just from nvim. Filterable by `cwd`. opencode supports list/resume/fork too.

`_establish_session` hardcodes `cwd = vim.fn.getcwd()` at creation time, so filtering the picker by `getcwd()` makes sessions vanish whenever nvim is opened in a subdirectory or the user `:cd`s. Filter by git root, matching session `cwd` as a prefix.

## Plugin-source gotchas

Each of these bit, or would have. Grouped by the step that has to deal with it.

**Adapters and connections (step 01)**

- The old `_establish_session` timeouts in `codecompanion.log` are **not** explained by cold start — `session/new` measures 1.3s today. **Root cause found and fixed (measured):** two global installs of `claude-agent-acp` exist on this machine — Homebrew's node has 0.59.0, and nvm's `v24.7.0/bin` has a forgotten **0.55.0**. `lua/config/options.lua`'s `ensure_nvm_path()` *prepended* nvm's bin dir, so every nvim spawn got 0.55.0, which answers `initialize` in 0.4s and then **never answers `session/new`** — no error, no stderr, no process exit. Reproduced outside CodeCompanion with raw `vim.system`, and reproduced in a plain shell by prepending the same directory; both versions work when invoked directly with either node binary, so it is the package version and not the node version. The fix is one word: append that directory instead of prepending. The earlier `CLAUDE_CODE_OAUTH_TOKEN` hypothesis is **falsified** — and note `env = {}` does not remove that variable from the agent's environment anyway, since `vim.system` inherits the parent environment and any shell that ran `claude setup-token` exports it. `env = {}` only stops CodeCompanion from *resolving* it, which is still worth doing.
- Because the guard in `claude/install.sh` is `command -v claude-agent-acp`, a stale copy earlier on `PATH` satisfies it and the newer version is never installed. A version check would be better than a presence check.
- Session config option values, read off live sessions (step 05 should re-resolve rather than trust this, since the set is model-dependent): claude `mode` = auto/default/acceptEdits/plan/dontAsk/bypassPermissions, `model` = default/sonnet/claude-fable-5[1m]/opus/haiku, `effort` (category `thought_level`) = default/low/medium/high/xhigh/max, `fast` (category `model_config`) = on/off, `agent` = 45 local subagents plus `default`. opencode: `model` = 41 ids, `mode` = build/plan. **`fast` is only present for models that offer it** — opus has it, sonnet does not — so sending it unconditionally logs a warning on every spawn.
- `interactions.chat.acp.defaults.apply(adapter, connection)` is chat-agnostic despite its path, and is what turns `defaults.session_config_options` into `session/set_config_option` calls. It applies `model` first, and silently skips (with a `log:warn`) any category the live session does not offer.
- **That silent skip is a safety problem for `mode`, not just a cosmetic one.** `apply` returns early when the agent advertised no `configOptions` at all, and `resolve_value` gives up when the requested value is not among the ones offered — either way the session keeps the agent's *default* mode. On claude that means write-capable tools, and since `mode = dontAsk` is the entire write defence (neither agent ever uses the client-mediated `fs/*` path, so a client-side write guard covers nothing in practice), a version bump that renames the option or changes its casing would quietly re-arm the thing this design exists to prevent. Read the value back off the live session — each option carries `currentValue`, and `set_config_option`'s response updates it — and refuse the connection when it did not stick. Fail closed; `findings.md`'s own history of 0.55 → 0.59 gaining the whole `configOptions` mechanism mid-investigation is the argument.
- **`PromptBuilder:cancel()` does not wait for the agent.** It sends the `session/cancel` notification and clears `connection._active_prompt` synchronously (`acp/prompt_builder.lua:294-313`). The agent keeps streaming for a while, and `handle_incoming_request_or_notification` routes whatever arrives to whatever `_active_prompt` is *now* (`acp/init.lua:662`) with no turn correlation at all — `forward_error_to_prompt` (`:603`) has no id check either. So a connection returned to the pool right after a cancel will fold the cancelled turn's trailing chunks into the next request's reply, and that concatenation reaches the buffer as a diff. A cancelled connection has to be dropped, not released; the respawn is the cheaper mistake.
- **A request that times out while still queued must release nothing and stay out of the queue.** With the waiter left in place, the next `release` → `pump` hands it a connection, marks it busy and sends the prompt anyway; `finish` then returns early because the request already resolved, so the connection is never released and the reaper skips it for being busy. Three of those exhaust the per-provider cap for the rest of the session. Check the resolved flag at the top of the waiter and hand the connection straight back.
- **Completion callbacks must not run inside the plugin's `handle_done` stack.** `PromptBuilder:handle_done` invokes `handlers.complete` and only *afterwards* clears `connection._active_prompt`. A callback that starts the next prompt inline therefore has its own new prompt nulled out, and every subsequent `session/update` is dropped — the second request simply never completes. Measured: reproducible 100% of the time, fixed by deferring the callback with `vim.schedule`.
- **Hook process death through the adapter's `handlers.on_exit`**, set on the per-spawn resolved adapter (`prepare_adapter` deepcopies, and deepcopy preserves function references). Without it, `kill -9` on an agent leaves a `ready` connection in the pool that later requests are handed, and the in-flight request waits out the full watchdog instead of failing at once. Ordering caveat: `handle_process_exit` calls `on_exit` *before* `_active_prompt:handle_done("canceled")`, so the exit must be flagged synchronously inside the hook or the completion path reports a plain "cancelled" and hides the crash.
- **The request watchdog has to cover the spawn, not just the prompt.** A stale or wedged agent accepts `initialize` and then never answers `session/new`; with the deadline armed only after acquisition that is an unreported hang forever. Arm it at send time and push it out again when the prompt goes on the wire, so time spent queued does not eat the reply's budget.
- `opencode-models.json` is stowed to `~/.local/config/opencode-models.json`, **not** `~/.config/opencode/`. `opencode-llm` checks the `~/.config` path first and falls back to a path relative to itself; anything else reading that file needs the same fallback or it silently finds nothing.
- The stock claude adapter declares `timeout = 20000`; the 90s value this config relies on is set in our own adapter definition, so **every** new adapter definition must restate it or silently inherit 20s.
- The claude adapter also ships `commands.yolo` (`claude-agent-acp --yolo`) — the exact opposite of what inline wants. Do not wire it.
- `Connection:disconnect()` is `assert(self._state.handle):kill(9)` — it **throws** on an already-dead process, which an idle reaper hits every cycle. `pcall` it and clear our own state regardless.
- The plugin registers a `VimLeavePre` autocmd per connection inside `connect_and_authenticate` (`acp/init.lua:149`) in a `clear = false` group and never removes it, so spawn/reap cycles accumulate one dead closure each. Harmless — every one is `pcall`ed onto a dead handle — but our own teardown uses a separate augroup we control.
- `send_rpc_request` yields via `async.wait` when `coroutine.running()`, and otherwise falls back to `wait_for_rpc_response`, which busy-waits on `vim.wait` up to the adapter timeout — 90s in this config. **All connection and session setup must run inside a coroutine** or the editor freezes.
- A `session/request_permission` arriving with no `_active_prompt` is dropped without any JSON-RPC reply at all (`acp/init.lua:666-670`), leaving the agent waiting forever on a connection that looks idle. Nothing arrives today, but this is another reason the per-request watchdog owns the timeout rather than trusting the agent to finish.
- Chat connections must stay separate from the inline pool: the `_loading_session and _on_session_update` branch (`acp/init.lua:660`) takes priority over `_active_prompt`, so a chat restoring history on a shared connection would swallow inline updates.
- Every spawn calls `log.new_response_file()`, so RPC logs accumulate one per spawn and want occasional pruning.

**Diffs and keymaps (step 03)**

- `DiffUI:setup_keymaps` binds `}` and `{` buffer-locally **even when `skip_default_keymaps` is set** (`diff/ui.lua:193-195`), shadowing the core paragraph motions while a diff is pending, and the second concurrent diff clobbers the first's. Delete both and rebind hunk navigation ourselves.
- That same branch binds *only* those two, so `g1` (always-accept) **disappears** from inline diffs, where it works today. Dropped deliberately: "always accept in this buffer" has no clear meaning once several diffs can be pending at once in one buffer.
- With `skip_default_keymaps`, `setup_close_handler` (`diff/ui.lua:533`) also **disables auto-reject on premature close**, so our registry must restore `from_lines` itself on `WinClosed`/`BufDelete` with a diff still pending.
- Diff accept/reject are `g1`/`g2`/`g3` from `interactions.shared.keymaps` (`config.lua:938-957`); the docs' `gda`/`gdr` are stale.
- Built-in `display.input` (`interactions/shared/input.lua`) is a cursor-relative floating input with prompt history; reused for the inline prompt.
- `resolve_diff` calls `clear_map(config.interactions.shared.keymaps, bufnr)` on every resolution, which deletes `g1`/`g2`/`g3`/`}`/`{` from the buffer — **including the `g2`/`g3` we bound ourselves**. Resolving one diff therefore unbinds a second pending diff's keys. Re-bind after each resolution.
- **`show_diff` on an empty buffer applies the reply twice.** `create_diff_display` (`diff/ui.lua:439`) writes `diff.merged.lines` — the interleaved old-and-new view — straight into the buffer whenever `buf_is_empty` (`utils/ui.lua:216`: one line, and that line empty), and `apply_inline` then applies its hunks on top. Measured: an insert of `local x = 1` / `local y = 2` into an empty buffer produces all four lines. There is nothing to diff against in an empty buffer, so inline writes the reply directly and leaves `u` as the way back.
- **`show_diff` takes over the current window when the target buffer is off screen.** `diff/ui.lua:426-429` falls back to `nvim_get_current_win()` and calls `nvim_win_set_buf` on it. Since requests run for seconds and moving on is normal, this yanks whatever the user went to read out of the window. Check `bufwinid(bufnr)` before calling it.
- **The whole-buffer diff picks its own hunk boundaries**, which need not fall inside the anchored range when neighbouring lines are identical. Two consequences, both accepted for now rather than fixed: a selection ending on a buffer's **empty last line** leaves that blank line behind (our `to_lines` is right; the plugin's hunks keep it), and with repeated identical lines a minimal diff can attribute the change to lines outside the range, so reject restores the wrong ones. The clean fix is to diff `[s0,e0)` against the reply and offset the hunks, rather than handing the plugin the whole buffer.
- `setup_banner` groups its autocmds as `codecompanion.diff_window_<bufnr>` with `clear = true` (`diff/ui.lua:452`) — keyed on the buffer, not the `diff_id`. A second concurrent diff in the same buffer therefore clears the first's banner refresh, and whichever resolves first deletes the shared group. Cosmetic: the banner stops updating, accept and reject still work.

**Autocmd semantics worth pinning down (step 03)**

- **`WinClosed` with `buffer = N` does fire**, and that is a trap rather than a convenience. The event's pattern is a *window* id, so `buffer =` resolves to "a window showing this buffer closed" — not "this buffer went away". Registering the reject-pending-diffs handler on it therefore destroys a finished, unaccepted edit when the user closes one split of two. Measured both ways. Count the remaining windows with `win_findbuf`, excluding the closing one from `args.match`, since `WinClosed` fires before the window is gone.
- `BufDelete`/`BufUnload` are the events that mean the buffer is really going. They are also the right place to cancel that buffer's in-flight requests — otherwise the agent runs to completion and the reply is discarded on arrival — and to drop the per-buffer registry entry and augroup, which nothing else ever reclaims.
- An extmark cannot sit on the row *after* the last line, so a selection running to the end of the buffer has its exclusive end anchor clamped onto the last line. Read the mark's column back to tell that apart from a mark genuinely at the start of that line — without it the region loses its final line and the reply's own last line is appended as a duplicate. Measured on all four transports before the fix.

**HTTP client (step 03)**

- On a 4xx, `Client:request` invokes the callback **twice**: first as `cb(nil, data)` with the error body as though it were a reply, then again with an error table (`http.lua:415-436`). The ollama adapter's `inline_output` then indexes `json.message.content` on an error body and throws. Check `data.status >= 400` before handing anything to the adapter's parser, and make the caller settle once.

**General**

- `strategies` is silently aliased to `interactions` (`config.lua:1377`).
- A third built-in interaction exists that the old plan predates: `interactions.cli`, which runs the real `claude`/`opencode` TUI in a terminal buffer. **Deliberately unused** — the ACP chat buffer is our single chat surface.
- `<leader>c` is free of conflicts in `lua/config/keymaps.lua`, whose comment block at lines 150-158 documents the current bindings and must be updated alongside them.
- `lazy.nvim` imports `lua/plugins/*.lua` non-recursively, so implementation modules must live outside that directory.
- `plenary.nvim` comes in as a CodeCompanion dependency and must stay in the spec's `dependencies`, even though nothing of ours uses it directly.

## Dependencies

`claude-agent-acp` is what the `claude_code` ACP adapter executes, and on this machine it is a global npm install (`/opt/homebrew/bin/claude-agent-acp` → `@agentclientprotocol/claude-agent-acp`). It was referenced in no installer, so a machine bootstrapped from this repo got no ACP bridge and every claude chat and inline request failed at spawn — the `ENOENT: 'claude-agent-acp'` already visible in `codecompanion.log`. `claude/install.sh` now guards it, alongside an `opencode` presence check, since the opencode chat adapter and the inline relay both shell out to it.

`OLLAMA_API_KEY` is already handled — sourced from `~/.config/ollama/ollama.env` by zsh's nested `.zshenv` — but the ollama **cloud** inline backend depends on it, so nvim must be started from a shell that has it exported.
