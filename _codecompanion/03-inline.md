# Step 03 — Inline

**Goal** The whole inline surface: prompt, placement, anchoring, diff, accept/reject, concurrency, cancellation, and the three transports behind one interface.

**Files**

- `nvim/.config/nvim/lua/ai/inline/init.lua` — everything except transport
- `nvim/.config/nvim/lua/ai/inline/http.lua` — ollama local + cloud
- `nvim/.config/nvim/lua/ai/inline/acp.lua` — claude and opencode over ACP
- `nvim/.config/nvim/lua/ai/inline/relay.lua` — opencode via `opencode-llm`
- `nvim/.config/nvim/lua/ai/ui.lua` — spinner/virt-text, message float

**Depends on** 01 (pool, adapters, providers) and 02 (parse).

**Evidence** `findings.md` → *Inline cannot use ACP adapters*, *Transport reach*, *The `fs` capability is inert*, *opencode over ACP: three permission configurations*, *Plugin-source gotchas → Diffs and keymaps*.

The contract is in `00-overview.md` → *The contract*. Do not restate it here; implement it.

Each transport implements `send(prompt, ctx, callbacks)`. Everything else — placement, anchoring, diffing, registry — is shared and lives in `init.lua`.

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

## Prose fallback

When the model answers instead of editing — which claude does on questions and on refusals, correctly — the buffer is left untouched and the message appears in a floating window anchored at the target range. `<CR>` opens a chat pre-loaded with the selection and the exchange; `q` dismisses.

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

- on a 40-line selection, per backend: the edit lands **only** inside the selection, unchanged lines are byte-identical, and `g3` restores the buffer exactly
- with no selection: code is inserted at the cursor and nothing else is touched
- asking a question ("what does this do?") on claude leaves the buffer untouched, shows the float, and `<CR>` opens a chat carrying the exchange
- a reply containing leaked `<tool_call>` markup leaves the buffer untouched and routes to the prose fallback
- two concurrent requests in different parts of one file: both diffs render, each `g2` accepts the right one, and accepting the first does not misplace the second
- deleting the anchored range mid-flight drops the request with a notification and no stray edit
- closing a buffer with a diff pending restores the original lines rather than leaving half-applied text
- `{` and `}` still perform their normal motions while a diff is pending
- **write refusal, per ACP transport**: point inline at a scratch file and instruct it to modify the file directly; the file is unchanged. Run on claude (`dontAsk`) and opencode (deny set), with both keymaps, including a shell-redirect instruction on claude
- **write refusal, buffer path**: same test with the target file open in nvim. Nothing exercises the client-mediated path today, so this is a regression check on the step 01 override — if `fs/write_text_file` ever does arrive, this is the test that catches the whole-buffer clobber
- **read exposure is real and bounded only by the prompt**: ask a claude or opencode request to read a file outside the repo. Expect success; confirm the reply routes to the prose fallback rather than into the buffer, and that no secret-bearing content is inserted anywhere
- **`cI` refuses on a tool-incapable provider**: select ollama, press `<leader>cI`, get a message naming the ACP transports, and no request sent
- **no leaked markup under the opencode deny set**: run `cI` on opencode against a repo-hungry prompt; the reply contains no `<tool_call>`/`<function=` markup
- failure paths — ollama cloud 401 and 429, relay non-zero exit, relay `-T` timeout — each surface as a notification and clear their virtual text
