# CodeCompanion rebuild — overview

## Why

The current nvim AI setup (`nvim/.config/nvim/lua/plugins/codecompanion.lua`) works but is unpleasant to use: inline edits run on local ollama and take up to two minutes, the model decides where its own output lands (so it can nuke a whole file), claude/opencode are chat-only, and every provider has a different, ad-hoc switching UX. This rebuilds the integration from zero around a single idea: **nvim owns placement, the model only supplies code**, with one shared option UX across all providers.

## How this directory is organised

| File | What it holds |
|---|---|
| `README.md` | This file: the contract, the module layout, the keymap table, the build order, and open items. |
| `findings.md` | All measured evidence and plugin-source citations. Cited by every step; owned by no step. Regenerated in part by step 07. |
| `00`…`08` | One self-contained work packet per build step. Each names its files, its dependencies, its spec, and its done-when checks. |

Read this file once, then work from a single step file. Steps cite `findings.md` rather than restating evidence, and cite this file for the keymap table — if you find the same fact written in two places, the copy is the bug.

## The contract

**nvim decides placement; the model returns code only.**

- visual selection → replace exactly that range
- no selection → insert at cursor
- the model never emits `placement`, so it can never route an edit into a chat or a new buffer, and can never widen the edit beyond the anchored range

The prompt embeds the selection, surrounding buffer context, and LSP diagnostics for the range. This replaces both current workarounds — the ollama `format` JSON schema and `FULL_SELECTION_HINT` — and is measured verbatim-clean on all five backends.

## Module layout

```
nvim/.config/nvim/
  lua/plugins/codecompanion.lua   lazy spec: deps, keymaps, setup(), adapter defs
  lua/ai/
    providers.lua                 single source of truth: providers, option schemas, defaults, current selection
    acp_pool.lua                  lazy connections, overflow spawning, idle reaping
    debug.lua                     :AiPoolStatus and :AiDebugSend — smoke harness, kept past step 01
    inline/init.lua               prompt, placement, extmark anchoring, request registry, diff, accept/reject dispatch
    inline/parse.lua              fence stripping, prose and tool-call-leak detection
    inline/http.lua               ollama_local + ollama_cloud
    inline/acp.lua                claude and opencode over ACP — `ci`/`cI` differ by prompt only
    inline/relay.lua              opencode via the `opencode-llm` script (`ci` only)
    chat.lua                      new chat with preset options, toggle, close-all
    chat_list.lua                 telescope picker: live chats + resumable sessions
    status.lua                    interactive option panel
    ui.lua                        spinner/virt-text helpers, option-cycling widget, message float
  tests/
    parse_spec.lua                plenary specs over recorded agent replies
    fixtures/                     saved replies: fenced+prose, bare code, leaked tool_call, refusal, question, verbatim rename

claude/.local/scripts/
  acp-capability-probe            re-runnable: regenerates the tables in findings.md
```

`providers.lua` is the keystone — inline, chat and status all read the same schema, which is what makes the UX shared instead of ad-hoc per provider.

## Providers

Three providers; ollama carries an `endpoint` dimension rather than being split in two.

| Provider | Options (inline) | Options (chat) | `<leader>cI` |
|---|---|---|---|
| `ollama` | endpoint `local`\|`cloud`, model, think | endpoint, model, think | unsupported — no tools exist |
| `claude` | model, effort, fast | model, effort, fast, mode, agent | yes, over ACP |
| `opencode` | model (relay free-tier list) | model, mode | yes, over ACP with mutation denied |

Model lists resolve dynamically — ollama local from `/api/tags`, ollama cloud from `https://ollama.com/api/tags`, claude from its session `configOptions`, opencode inline from `free_models` in `opencode/.local/config/opencode-models.json` — and are cached per nvim session.

Defaults, free-first per `AGENTS.md`:

- inline: `ollama` / `cloud` / `gpt-oss:120b` — 3.9s on a 57-line selection, free, no local RAM cost
- chat: `claude` / `opus` / effort `xhigh` / mode `acceptEdits`
- opencode: pinned to a free `opencode/*-free` model, never the ambient `big-pickle`

## Key bindings

Canonical table — steps cite this rather than restating it. All under `<leader>c`, which is unused elsewhere in `lua/config/keymaps.lua`.

The **Step** column is load-bearing, not decoration: after step 00 strips every binding, a key that no step claims is a key that never comes back. Any new row needs an owner here before it is real.

| Key | Mode | Action | Step |
|---|---|---|---|
| `<leader>ci` | n, x | Inline prompt (forbids tool use) | 03 |
| `<leader>cI` | n, x | Inline prompt inviting repo reads (ACP transports only) | 03 |
| `<leader>cm` | n | Switch inline backend / model | 03 |
| `<leader>cx` | n | Cancel inline request(s) | 03 |
| `<leader>cj` / `<leader>ck` | n | Next / previous hunk in the diff under the cursor | 03 |
| `g2` / `g3` | n | Accept / reject diff under cursor | 03 |
| `<leader>cc` | n | Toggle last chat (message if none) | 01 plugin-native, 04 new-style |
| `<leader>ca` | n, x | Action palette | 01 (plugin-native, never ours) |
| `<leader>cn` | n, x | New chat with current provider + options | 04 |
| `<leader>cq` | n | Close all chats | 04 |
| `<leader>cs` | n | Status panel | 05 |
| `<leader>cl` | n | Chat list | 06 |
| `ga`, `gd`, `/…` | n | Plugin-native, inside the chat buffer | 01 (arrives with the adapters) |

Three changes from today's bindings: `<leader>ct` is gone, since `think` is a status-panel row like every other provider option; `<leader>cx` no longer resets a stuck busy flag — it cancels in-flight requests; and `g1` (always-accept) is gone, because `skip_default_keymaps` stops the plugin binding it and per-buffer blanket approval is meaningless once several diffs can be pending in one buffer. The comment block at `lua/config/keymaps.lua:150-158` documents all three as they are today and must be updated with them (step 08).

## Build order

The spike that gated this plan is **done**, and so are the questions it left open — see `findings.md`. Dependencies are real: 02 and 03 both need 01, and nothing after 01 can be tested without it.

| Step | File | Delivers | Depends on |
|---|---|---|---|
| 00 | `00-strip.md` | the old integration deleted; a bare plugin spec | — |
| 01 | `01-providers-pool.md` | `providers.lua`, `acp_pool.lua`, the adapter definitions, the debug harness | 00 |
| 02 | `02-parse-tests.md` | `inline/parse.lua` + plenary specs and fixtures | — |
| 03 | `03-inline.md` | `inline/init.lua` and the four transports | 01, 02 |
| 04 | `04-chat.md` | `chat.lua` | 01 |
| 05 | `05-status.md` | `status.lua` | 01, 04 |
| 06 | `06-chat-list.md` | `chat_list.lua` | 01, 04 |
| 07 | `07-probe.md` | `acp-capability-probe` | — |
| 08 | `08-final-audit.md` | keymap comment block restored, full audit | 03–06 |

Three notes on the ordering. **00 demolishes before anything is built**, so no later step negotiates with the old config — see *Clean slate* below. Adapter definitions live in **01**, not 04 where an earlier draft had them: the pool spawns connections *from* adapters, so inline would otherwise depend on a step that comes after it. And **07 has no dependencies at all and should be pulled early** — its assertions are what keep `findings.md` honest, and three of them currently exist only as throwaway scripts in a session scratchpad.

## Clean slate

Step 00 deletes the existing integration outright rather than migrating it feature by feature. Keeping both alive would mean every step from 01 to 08 reasoning about two implementations bound to the same keys, for the sake of a fallback that git already provides.

The consequence is a **blackout**: after step 00 there is no AI integration in nvim at all. Step 01 ends it by restoring the adapters, which also brings back the plugin's native chat and action palette. So the window is 00 → 01, not 00 → 03 — keep those two together and the outage is short.

Two rules follow from this and are worth stating because they are what make the per-step tables below true:

1. **Every binding has exactly one owning step**, recorded in the Step column of *Key bindings*. After 00 strips them all, a key no step claims is a key that never returns.
2. **No step depends on anything the old config provided.** Where a step needs something the old config used to supply, it builds it — which is why 01 carries the debug harness and re-binds the two plugin-native keys.

## Working state after each step

| After | Usable end to end | How to exercise it | Not yet available |
|---|---|---|---|
| 00 | **nothing** — this is the blackout | `:CodeCompanionChat` opens and fails on the missing adapter, which is the correct bare-plugin state | everything |
| 01 | plugin-native chat and action palette — `cc`, `ca`, and `ga`/`gd` inside a chat | `:AiPoolStatus`, `:AiDebugSend`, and a real chat | inline, status, chat list, preset chat options |
| 02 | no change to what is pressable | `plenary` specs over `tests/fixtures/` | as above |
| 03 | **inline, fully** — `ci`, `cI`, `cm`, `cx`, `cj`/`ck`, `g2`/`g3`, all four transports | real edits in real buffers | status, chat list, preset chat options |
| 04 | new-style chat — `cn`, `cq`, `cc` upgraded; the prose float's `<CR>` stops degrading | real chats, `gd` debug window | status, chat list |
| 05 | status panel — `cs` | panel plus `gd` to confirm it reached the session | chat list |
| 06 | chat list — `cl` | picker, including a session started in a terminal | — |
| 07 | the probe script | run it; independent of nvim entirely | — |
| 08 | no new behaviour — audit and docs only | keymap audit against the table above | — |

So: **01 is the shortest hop back to something usable, and 03 is the first milestone worth living on.** Inline is the pain this rebuild exists for, which is why it precedes chat despite chat being simpler.

## Open items

- **`claude/install.sh` guards `claude-agent-acp` with `command -v`**, which a stale copy earlier on `PATH` satisfies — exactly the 0.55.0-shadowing-0.59.0 situation that cost this build a debugging session (`findings.md`). A version check would be better than a presence check. Not urgent now that `ensure_nvm_path()` appends, but the guard is still weaker than it looks.
- **Opening a chat logs `Could not find the rules file '../../agents/.agents/AGENTS.md'`.** CodeCompanion resolves the `@import` in `~/.claude/CLAUDE.md` relative to the cwd rather than to the importing file. Cosmetic, predates this rebuild, and unrelated to any step here — noted so it is not mistaken for a regression.
- **Revisit the opencode inline transport** — the next concrete experiment is overriding the ACP agent's *prompt* via `OPENCODE_CONFIG_CONTENT` alongside the deny set, to recover the relay's steering (and possibly some of the 40s) inside an ACP session. Also whether a future release lets a client refuse tools over ACP, and whether a faster free model cuts the relay's ~9.3s. See step 03.
- **Accepted risk: inline on either ACP transport can read any file the user can** and echo it into a reply. No session mode or permission set constrains reads on claude, and opencode's `cI` config allows them deliberately; our own read handler is never used by either. Recorded rather than solved. The real levers, if it ever needs solving, are running the agent under a confined cwd or restricting `cI` to the relay — both worth reconsidering if a future release adds client-refusable reads. `ci` on ollama or the relay is unaffected: those cannot read at all.
- **`<leader>cI` on claude is prompt-deep only.** Same adapter, pool, mode and capabilities as `ci`; only the wording differs. The behavioural gap is large enough to justify the keymap (~5s and no tools versus ~27s and repo reads) but it is a speed-and-intent choice, not a boundary, and must not be documented as one. On opencode the two are genuinely different transports, and on ollama `cI` does not exist — so the pair means something different on each provider, which is a UX wart worth watching once it is in use.
- ~~Add the `claude-agent-acp` install guard~~ — resolved: `claude/install.sh` now guards it, plus an `opencode` presence check.
- ~~Where do the capability probes live?~~ — resolved: `claude/.local/scripts/acp-capability-probe`, step 07, with `tests/fixtures/` holding the recorded replies the parser is tested against.
- ~~Confirm that claude's `dontAsk` mode actually refuses writes~~ — resolved: it denies `Edit` and mutating shell commands while leaving reads working, verified against bytes on disk. Since the client `fs/*` path goes unused by both agents, this mode *is* the write defence on claude rather than one layer of two.
- ~~Whether inline should expose claude's `agent` option~~ — resolved: no. Agent selection stays chat-only. The subagent definitions are written for autonomous multi-step work (`implementer`'s own description mandates a "Pre-pass: Grep target symbol across codebase"), which pushes toward the tool-seeking and prose that inline exists to avoid.
- ~~ollama cloud free-tier list~~ — resolved: `gpt-oss:20b`, `gpt-oss:120b`, `gemma4:31b`, `nemotron-3-super` confirmed; `ollama-cloud/qwen3.5:397b` needs a paid subscription and has been removed from `free_models` in `opencode-models.json`.
- ~~Whether to surface opencode's `mode` for inline~~ — moot: the relay transport has no ACP session.
