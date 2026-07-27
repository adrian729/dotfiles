# Step 03 — Inline

**Goal** The whole inline surface: prompt, placement, anchoring, diff, accept/reject, concurrency, cancellation, and the three transports behind one interface.

**Files**

- `nvim/.config/nvim/lua/ai/inline/init.lua` — everything except transport
- `nvim/.config/nvim/lua/ai/inline/http.lua` — ollama local + cloud
- `nvim/.config/nvim/lua/ai/inline/acp.lua` — claude and opencode over ACP
- `nvim/.config/nvim/lua/ai/inline/relay.lua` — opencode via `opencode-llm`
- `nvim/.config/nvim/lua/ai/ui.lua` — spinner/virt-text, message float

**Depends on** 01 (pool, adapters, providers) and 02 (parse). Soft dependency on 04 for one thing only — see *Prose fallback*.

**Leaves a working state**: after this step inline is complete on every transport and the old inline path can be retired from the keymap. This is the intended first milestone.

**Evidence** `findings.md` → *Inline cannot use ACP adapters*, *Transport reach*, *The `fs` capability is inert*, *opencode over ACP: three permission configurations*, *Plugin-source gotchas → Diffs and keymaps*.

The contract is in `README.md` → *The contract*. Do not restate it here; implement it.

Each transport implements `send(prompt, ctx, callbacks)`. Everything else — placement, anchoring, diffing, registry — is shared and lives in `init.lua`.

## One prompt contract, for every transport

All four transports get the same instruction block. Do not give HTTP and the relay a structured envelope such as `{"code":"…"}` on the theory that it parses more cleanly — that was tried and reverted, and it fails three ways. Measured on ollama cloud against the same C selection: under the envelope the model returned **the whole enclosing function, `<before>` and `<after>` context included**, where the plain contract returned exactly the selected lines. No brace-matching extractor survives a code fragment whose braces do not balance — `{"code":"if (x) {\n  go()\n"}` never closes, so the decode is skipped and the raw JSON goes into the buffer as if it were the reply. And it is the very workaround this rebuild exists to delete: README → *The contract* names the ollama `format` JSON schema as one of the two things the new prompt replaces.

## Placement and anchoring

Each request anchors its target range with an **extmark** at send time, so edits landing elsewhere — including another inline accept — shift it correctly. The built-in snapshots whole-buffer line numbers instead, which is why two of its requests corrupt each other.

If the anchored range is deleted mid-flight, drop the result with a notification rather than applying it at a guessed position.

## Diff and accept/reject

`show_diff` renders and tracks; it does not apply or revert. All buffer mutation is ours.

- call it with `skip_default_keymaps = true`
- our own `g2`/`g3` dispatch to the diff whose range contains the cursor, calling `require("codecompanion.diff.keymaps").accept_change.callback(diff_ui)` so the plugin's `resolve_diff` bookkeeping is reused rather than reimplemented
- delete the `}`/`{` maps the plugin binds anyway, and put hunk navigation on `<leader>cj` / `<leader>ck`, dispatched by cursor position like accept/reject
- auto-reject-on-close is disabled under `skip_default_keymaps`, so the registry restores the original lines itself on `WinClosed`/`BufDelete` with a diff still pending

A per-buffer registry tracks pending requests and rendered diffs.

**Known limitation, deliberately not fixed here.** The diff is computed over the *whole buffer* — `show_diff` wants whole-buffer coordinates — so the plugin chooses hunk boundaries that are not guaranteed to fall inside the anchored range when neighbouring lines happen to be identical. Two visible effects: a selection ending on a buffer's empty last line leaves that blank line behind, and in a run of identical lines a minimal diff can attribute the change outside the range, so reject restores the wrong lines. Both are cosmetic-to-minor and neither loses content silently, but the clean fix is to diff only `[s0, e0)` against the reply and offset the resulting hunks — a change to how the diff is fed, not a patch on top of it, which is why it is its own piece of work rather than a footnote in this step.

## Prose fallback

When the model answers instead of editing — which claude does on questions and on refusals, correctly — the buffer is left untouched and the message appears in a floating window anchored at the target range. `<CR>` opens a chat pre-loaded with the selection and the exchange; `q` dismisses.

**This float is the exception, not a routine outcome.** It fires on three things and nothing else: leaked tool markup, an explicit refusal, and an answer in prose where a code edit was asked for. Everything else goes to the buffer as a diff. Step 02 → *Prose must be proven, not inferred* has the rule and the measurements behind it; the short version is that an over-eager prose test is far more damaging than an over-eager edit, because the edit is one `g3` away from being undone while the rejected edit is simply lost.

The float also has to catch a case the original plan missed: a model that declines usually returns the **selection unchanged inside a fence** with its reasons in prose around it. That parses as code, produces no change, and reporting only "nothing to change" throws the explanation away — the user waits, gets nothing, and is told nothing. So when the parsed code turns out to match the buffer and the reply carried a preamble, show the preamble in the float instead of a notification. Measured: claude does this on every refusal, so it is the common path, not an edge case. Content-free lead-ins do not count as a preamble — "Here's the updated code:" above an unchanged selection is a notification, not a float.

That `<CR>` is the **only** part of this step that needs step 04. Until `ai/chat.lua` exists, degrade it to the plugin-native `:CodeCompanionChat` without the pre-loaded exchange, and leave a marker so step 04 upgrades it. That target works because step 01 restored the adapters. Do not reorder for this — inline is the milestone worth reaching first, and the degraded path is a few lines.

This is also where a leaked-tool-call reply lands, per step 02.

## Visual feedback

Per-request virtual text at the anchored range — not a cursor-relative float, since several must be visible at once: spinner frame, provider/model, and the prompt trimmed with an ellipsis to fit the window. Cleared on completion, error, or cancel.

## Cancellation

`<leader>cx` cancels the request under the cursor, or all in-flight in the buffer. Per transport: ACP sends `session/cancel` via `PromptBuilder:cancel()`; HTTP kills the job handle returned by `Client:request` (`http.lua:378`); the relay kills the `vim.system` handle for the `opencode-llm` subprocess.

## The two keymaps

Both work with **any** selected provider. Neither is tied to a backend, and neither is defined by a capability — those are inert. They differ only in the prompt they send. Reach varies by transport, per `findings.md` → *Transport reach*.

- **`<leader>ci`** — prompt **forbids** tool use. On HTTP and relay that is structurally guaranteed; on the two ACP transports it is steering only, and the request can still read the machine. The status panel's reach marker (step 05) is what makes the difference visible.
- **`<leader>cI`** — same placement contract, prompt **invites** repo research. Available on claude over ACP (~27s on a context-hungry ask, prose prefixed before the fenced code) and opencode over ACP (~40s under the write-denying set). On ollama and the relay it is *meaningless*, since those cannot read anything: refuse with a message naming the transports that support it rather than silently running `ci` semantics and returning something the prompt did not ask for.

Write safety on both comes from the session mode or permission set configured in step 01, since that governs the agents' own tools — the only path either agent uses.

## opencode transport split

`ci` uses the **relay**; `cI` uses **ACP**.

The relay is `opencode run --agent relay --dir <neutral>`: guaranteed tool-free, no repo access, free model, ~9.3s. Invoke it by shelling out to the existing `opencode-llm` script rather than composing `opencode run` ourselves — it already handles the free-model fallback walk from `opencode-models.json`'s `relay` list, the neutral cwd, the portable timeout wrapper, and `--format json` parsing, and its contract is exactly what inline needs (content on stdin, prompt as args, answer on stdout). Use `-T` for the timeout; `-o` is not wanted here.

Why the relay wins for `ci`: `opencode acp` has no `--agent` flag, and denying a tool the model wants stops the execution but not the attempt, so tool-call markup leaks into the reply as text. The relay pairs the same deny set with a **prompt** telling the model it has no tools, stopping the attempt at source.

For `cI`, repo reading is the point, so ACP is right and the leak is avoidable — allow reads and it disappears. Costs are recorded in `findings.md`; `cI` on opencode is the slowest path in this plan and prose-prone on repo-hungry asks. Prose routes to the fallback float, so it degrades visibly rather than corrupting a buffer.

**Still to revisit**: overriding the ACP agent's *prompt* via `OPENCODE_CONFIG_CONTENT` alongside the deny set, to recover the relay's steering — and with it, possibly, some of the 40s — inside an ACP session.

## Out of scope

`:CodeCompanionCmd` is HTTP-only in the plugin too. It stays on the ollama adapter and is not part of this module.

## Done when

- on a real selection, per backend: the edit lands **only** inside the selection, unchanged lines are byte-identical, and `g3` restores the buffer exactly
- a selection running to the **last line of the buffer** keeps that line — the exclusive end anchor has no row to sit on and gets clamped, which drops the final line and duplicates the reply's last one. Carry that fact as a flag on the mark set, **not** as the mark's column: on a buffer whose last line is empty, "end of the last line" and "start of the last line" are the same column, so column-sniffing loses a line again on exactly the buffers that end in a blank one
- a diff whose first hunk is on **line 1** leaves no spacer line behind, on accept and on reject alike
- with no selection: code is inserted at the cursor and nothing else is touched
- asking a question ("what does this do?") on claude leaves the buffer untouched, shows the float, and `<CR>` opens a chat carrying the exchange
- a reply containing leaked `<tool_call>` markup leaves the buffer untouched and routes to the prose fallback
- **the float does not fire on ordinary edits**: a one-sentence rewrite in a Markdown buffer, a `SELECT` list widened in a `.sql` file, and a two-line shell edit all land as diffs. This is the check the shipped heuristic failed on nine of twenty replies
- **and not on one-line edits either** — `SELECT id, email FROM users`, `set -eu -o pipefail`, `-- Returns the sum of the two arguments.` all place. A single-line reply is the case a sentence test is most likely to get wrong, because there is no second line to contradict it
- **an empty buffer gets the reply once**, not twice, and not wrapped in a diff — there is nothing to diff against, and DiffUI writes its merged view straight in when it finds the buffer empty
- **a request whose buffer left the screen does not drag it back**: fire a request, switch to another file, and the reply reports itself without changing which buffer the window is showing
- **closing one split of two leaves a pending diff alone**; only closing the last window showing the buffer rejects it. `WinClosed` scoped with `buffer =` fires for either, so this needs a window count
- deleting the buffer cancels that buffer's in-flight requests rather than letting them run to completion into a discarded result
- **no structured envelope is requested**: the prompt sent on every transport contains the contract once and no `{"code":…}` instruction
- a transport that fails synchronously — `opencode-llm` off `PATH`, an adapter that will not resolve — leaves nothing behind in the buffer's request registry
- the prompt's `<file path=…>` is repo-relative, not an absolute path out of the user's home directory
- two concurrent requests in different parts of one file: both diffs render, each `g2` accepts the right one, and accepting the first does not misplace the second
- deleting the anchored range mid-flight drops the request with a notification and no stray edit
- closing a buffer with a diff pending restores the original lines rather than leaving half-applied text
- `{` and `}` still perform their normal motions while a diff is pending
- **write refusal, per ACP transport**: point inline at a scratch file and instruct it to modify the file directly; the file is unchanged. Run on claude (`dontAsk`) and opencode (deny set), with both keymaps, including a shell-redirect instruction on claude
- **write refusal, buffer path**: same test with the target file open in nvim. Nothing exercises the client-mediated path today, so this is a regression check on the step 01 override — if `fs/write_text_file` ever does arrive, this is the test that catches the whole-buffer clobber
- **read exposure**: ask a claude or opencode request to read a file outside the repo. What must hold is that no secret-bearing content reaches the buffer and the reply is shown, not inserted. Whether the agent complies is its own judgement and must not be asserted — measured through the finished inline path, claude declined twice as an injection attempt, while the bare protocol probe read the file happily (`findings.md`)
- **`cI` refuses on a tool-incapable provider**: select ollama, press `<leader>cI`, get a message naming the ACP transports, and no request sent
- **no leaked markup under the opencode deny set**: run `cI` on opencode against a repo-hungry prompt; the reply contains no `<tool_call>`/`<function=` markup
- failure paths — ollama cloud 401 and 429, relay non-zero exit, relay `-T` timeout — each surface as a notification and clear their virtual text
- `<leader>ci`, `<leader>cI`, `<leader>cm`, `<leader>cx`, `<leader>cj`/`<leader>ck` and `g2`/`g3` are bound for the first time since step 00, and `:map <leader>c` shows exactly these plus step 01's `cc`/`ca`
- step 01's chat and action palette still work — this step adds bindings and touches none of them
