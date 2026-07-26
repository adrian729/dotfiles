# CodeCompanion rebuild — overview

## Why

The current nvim AI setup (`nvim/.config/nvim/lua/plugins/codecompanion.lua`) works but is unpleasant to use: inline edits run on local ollama and take up to two minutes, the model decides where its own output lands (so it can nuke a whole file), claude/opencode are chat-only, and every provider has a different, ad-hoc switching UX. This rebuilds the integration from zero around a single idea: **nvim owns placement, the model only supplies code**, with one shared option UX across all providers.

## How this directory is organised

| File | What it holds |
|---|---|
| `findings.md` | All measured evidence and plugin-source citations. Cited by every step; owned by no step. Regenerated in part by step 07. |
| `00-overview.md` | This file: the contract, the module layout, the keymap table, the build order, and open items. |
| `01`…`08` | One self-contained work packet per build step. Each names its files, its dependencies, its spec, and its done-when checks. |

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

| Key | Mode | Action |
|---|---|---|
| `<leader>ci` | n, x | Inline prompt (forbids tool use) |
| `<leader>cI` | n, x | Inline prompt inviting repo reads (ACP transports only) |
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

Three changes from today's bindings: `<leader>ct` is gone, since `think` is a status-panel row like every other provider option; `<leader>cx` no longer resets a stuck busy flag — it cancels in-flight requests; and `g1` (always-accept) is gone, because `skip_default_keymaps` stops the plugin binding it and per-buffer blanket approval is meaningless once several diffs can be pending in one buffer. The comment block at `lua/config/keymaps.lua:150-158` documents all three as they are today and must be updated with them (step 08).

## Build order

The spike that gated this plan is **done**, and so are the questions it left open — see `findings.md`. Dependencies are real: 02 and 03 both need 01, and nothing after 01 can be tested without it.

| Step | File | Delivers | Depends on |
|---|---|---|---|
| 01 | `01-providers-pool.md` | `providers.lua`, `acp_pool.lua`, **and the adapter definitions** | — |
| 02 | `02-parse-tests.md` | `inline/parse.lua` + plenary specs and fixtures | — |
| 03 | `03-inline.md` | `inline/init.lua` and the three transports | 01, 02 |
| 04 | `04-chat.md` | `chat.lua` | 01 |
| 05 | `05-status.md` | `status.lua` | 01, 04 |
| 06 | `06-chat-list.md` | `chat_list.lua` | 01, 04 |
| 07 | `07-probe.md` | `acp-capability-probe` | — |
| 08 | `08-retire-old.md` | old config retired, keymap comment block updated | 03–06 |

Two notes on the ordering. Adapter definitions moved into **01**, not 04 where an earlier draft had them: the pool spawns connections *from* adapters, so inline (03) would otherwise depend on a step that comes after it. And **07 has no dependencies and should be pulled early** — its assertions are what keep `findings.md` honest, and three of them currently exist only as throwaway scripts in a session scratchpad.

## Open items

- **Revisit the opencode inline transport** — the next concrete experiment is overriding the ACP agent's *prompt* via `OPENCODE_CONFIG_CONTENT` alongside the deny set, to recover the relay's steering (and possibly some of the 40s) inside an ACP session. Also whether a future release lets a client refuse tools over ACP, and whether a faster free model cuts the relay's ~9.3s. See step 03.
- **Accepted risk: inline on either ACP transport can read any file the user can** and echo it into a reply. No session mode or permission set constrains reads on claude, and opencode's `cI` config allows them deliberately; our own read handler is never used by either. Recorded rather than solved. The real levers, if it ever needs solving, are running the agent under a confined cwd or restricting `cI` to the relay — both worth reconsidering if a future release adds client-refusable reads. `ci` on ollama or the relay is unaffected: those cannot read at all.
- **`<leader>cI` on claude is prompt-deep only.** Same adapter, pool, mode and capabilities as `ci`; only the wording differs. The behavioural gap is large enough to justify the keymap (~5s and no tools versus ~27s and repo reads) but it is a speed-and-intent choice, not a boundary, and must not be documented as one. On opencode the two are genuinely different transports, and on ollama `cI` does not exist — so the pair means something different on each provider, which is a UX wart worth watching once it is in use.
- ~~Add the `claude-agent-acp` install guard~~ — resolved: `claude/install.sh` now guards it, plus an `opencode` presence check.
- ~~Where do the capability probes live?~~ — resolved: `claude/.local/scripts/acp-capability-probe`, step 07, with `tests/fixtures/` holding the recorded replies the parser is tested against.
- ~~Confirm that claude's `dontAsk` mode actually refuses writes~~ — resolved: it denies `Edit` and mutating shell commands while leaving reads working, verified against bytes on disk. Since the client `fs/*` path goes unused by both agents, this mode *is* the write defence on claude rather than one layer of two.
- ~~Whether inline should expose claude's `agent` option~~ — resolved: no. Agent selection stays chat-only. The subagent definitions are written for autonomous multi-step work (`implementer`'s own description mandates a "Pre-pass: Grep target symbol across codebase"), which pushes toward the tool-seeking and prose that inline exists to avoid.
- ~~ollama cloud free-tier list~~ — resolved: `gpt-oss:20b`, `gpt-oss:120b`, `gemma4:31b`, `nemotron-3-super` confirmed; `ollama-cloud/qwen3.5:397b` needs a paid subscription and has been removed from `free_models` in `opencode-models.json`.
- ~~Whether to surface opencode's `mode` for inline~~ — moot: the relay transport has no ACP session.
