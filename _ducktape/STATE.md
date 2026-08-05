# Where we left off

Companion to `PLAN.md` in this directory, which is the approved plan and remains the
specification. This file records what is actually built, what was learned building it, and what
comes next.

Last updated after step 9 of 9 — the dotfiles switch is done. (Step 7, publishing, remains out
of scope by the user's decision, independent of steps 8/9 — see below, it happened anyway via the
repo's own remote, just not as a deliberate act of this work.)

## The one-line summary

`~/projects/ducktape.nvim` exists as a working, published plugin with 12 commits and 603 passing
assertions, verified end to end in a throwaway config against live agents, and now also verified
against the real dotfiles. The dotfiles switch (`PLAN.md` step 9) has been executed: `lua/ai/` is
gone, `lua/plugins/codecompanion.lua` consumes `ducktape.nvim` via lazy.nvim's `dev` override, and
chat history has been merged into the plugin's own state directory.

## Repo state

`~/projects/ducktape.nvim`, branch `main`, clean working tree. `origin` is
`git@github.com:adrian729/ducktape.nvim.git` (public, real GitHub repo), local `main` up to date
with `origin/main`. Still no version tag — `release-please` has opened its branch
(`release-please--branches--main`) but nothing has merged it yet, which is fine: tags only gate
`version = "*"` semver pinning, not normal lazy.nvim use.

```
2608193  docs: regenerate doc/ducktape.txt
7b248b5  feat: discover model lists on first setup, and add a refresh keymap
2cb3667  feat: discover model lists per machine instead of reading a dotfiles config
12443fa  fix(ci): create doc/ before panvimdoc writes into it
48037ef  chore: point the install snippets at the repo owner
8939354  fix: name real keys in two messages and one mapping description
8e0d736  test: keep the parity scripts that exercised the packaging
002aa75  fix: honour keymaps = false on the vim.g route
07a941c  docs: add the README, reconcile the imported docs, wire vimdoc and CI
d22f6b5  Wire the extension, the plugin script, health and the manifests
7e1eb17  Add the configuration surface and the key lookup
55f9ec5  Import the ai layer from dotfiles as ducktape.nvim
```

The five commits above `8939354` postdate this doc's previous update: model discovery moved from a
dotfiles-sourced `opencode-models.json` to live per-machine discovery (`lua/ducktape/model_cache.lua`),
which added an 18th global keymap (`<leader>cmr`, refresh models) — the dotfiles-side "empty `opts`
reproduces this machine's config exactly" claim is now slightly less true than it reads: model lists
are no longer sourced from these dotfiles at all.

| Path | What is there |
|---|---|
| `lua/ducktape/` | the 11 imported modules, plus new `init.lua`, `config.lua`, `keys.lua`, `health.lua` |
| `lua/ducktape/inline/` | the 6 inline modules, imported |
| `lua/codecompanion/_extensions/ducktape/init.lua` | extension entry point, closures only in `exports` |
| `plugin/ducktape.lua` | `<Plug>` maps, `<leader>c*` defaults, statusline injection, `:Ducktape` |
| `tests/` | 11 suites, 6 probes, `minimal_init.lua`, `run_tests.sh`, and `parity/` (8 scripts + README) |
| `docs/` | the three `_nvim_ai` files, renamed and reconciled against the code |
| `scripts/vimdoc.md` | the panvimdoc source: README + keymaps + how_to_use |
| `.github/workflows/` | `ci.yml` (stylua, lua_ls, tests on 0.11.4/stable/nightly), `docs.yml`, `release.yml` |
| root | `README.md`, `Makefile`, `lazy.lua`, `pkg.json`, `minimal.lua`, `LICENSE` (MIT), `.luarc.json` |

**603 passed, 0 failed across 12 suites.** `stylua --check lua/ plugin/ tests/` clean.

```
test_capture 22   test_chat_edit 82   test_inline_guard 101   test_inline_list_edges 76
test_inline_list 43   test_keys 45   test_models 22 (new)   test_say 17   test_settle_all 74
test_shift 18   test_waiting 84   test_wiring 19
```

The original 517 are unchanged per suite, which is the parity claim. `test_models` is new (the
per-machine model-discovery work); `test_keys` grew 43 → 45 covering the 18th keymap.

Run them with `cd ~/projects/ducktape.nvim && ./tests/run_tests.sh` (add a path to run one).

## Dotfiles state — step 9 executed

`nvim/.config/nvim/lua/ai/` is gone (`git rm -r`). `lua/plugins/codecompanion.lua` is now two
sibling specs — `{ "adrian729/ducktape.nvim", lazy = false }` and `olimorris/codecompanion.nvim`
(`event = "VeryLazy"` kept, `opts.extensions.ducktape = { opts = {} }`) — instead of the old
`keys`-table-plus-adapter-`config` monolith. `lua/config/lazy.lua` gained a `dev` block:
`{ path = "~/projects", patterns = { "adrian729" }, fallback = true }`, consuming the local
`~/projects/ducktape.nvim` checkout on this machine and falling back to a normal GitHub clone
elsewhere — chosen over this doc's own step-9 recipe's hardcoded `dir = vim.fn.expand(...)`
specifically for that portability. `fallback = true` is not optional: lazy.nvim's `dev.patterns`
matching (`lazy/core/meta.lua`) forces `plugin.dir` to the local path unconditionally when
`fallback` is left at its default `false`, even if that path doesn't exist — that would break
every machine but this one. `lua/config/options.lua`'s statusline-injection block is removed
(`plugin/ducktape.lua` injects the equivalent itself). `lua/config/keymaps.lua`'s stale AI-keymap
comment now points at the plugin's own `docs/keymaps.md` instead of re-listing keys that drift.
`nvim/_nvim_ai/{how_to_use,implementation,keymaps}.md` are now stubs pointing at the plugin's docs
(kept rather than deleted, per this doc's own step-7 intent, so existing links stay meaningful).

State directories were merged, not just moved: `~/.local/state/nvim/ducktape/` already existed
with real content (`models.json`, a genuine discovered-model cache) from earlier testing, so
`ai/chat_sessions.json` and `ai/chat_titles.json` were copied in (verified byte-identical with
`cmp` before deleting the source) rather than `mv`d wholesale, and `models.json` was left alone.
Both directories were snapshotted with a timestamped `cp -R` backup before any of this work began,
including before running this repo's own test suite — which, unlike the throwaway step-8 parity
config, runs against the real `$XDG_STATE_HOME`.

Full verification pass, done directly against the real config rather than a throwaway swap this
time (parity was already proven once in step 8): before any keypress, `codecompanion` and
`ducktape.chat` are both unloaded (confirmed via a headless, no-sleep check); pressing `<leader>ci`
loads `ducktape.inline` specifically (not just "whatever `VeryLazy` happened to load by then" —
worth noting, `VeryLazy` itself never fires in pure `--headless` mode with no UI attached, since
it waits on `UIEnter`, which needs an actual attached UI; real interactive usage is unaffected,
this only matters for how you write a headless test for it). All 18 global keymaps resolved via
`maparg`. `require("ducktape").is_ready()` is `true`. `codecompanion.adapters.resolve("claude_code")`
shows `dontAsk` / `90000` / no `yolo`; `resolve("opencode")` shows `OPENCODE_PERMISSION` in `env` —
the hardened adapters, not codecompanion's stock ones. Chat persistence survived two full restarts,
including the one right after the state-directory merge.

## What was built beyond a straight copy

Three things, and only three, per the plan's ground rule.

1. **`config.lua`** — every knob, with the extracted configuration's own values as defaults, so
   empty `opts` reproduces it exactly. Provider specs, per-provider defaults and the adapter
   definitions moved as data, unchanged. Two config routes: `vim.g.ducktape` for `keymaps` and
   `statusline` (read at plugin-script time), extension `opts` for everything else.
2. **`keys.lua`** — one lookup for what a key is called; the ~25 messages, the chat footer and the
   chat list legend read from it. The footer and legend became functions, since as constants they
   would have frozen the defaults at load time.
3. **`init.lua`'s bootstrap contract** — restores an invariant the move broke. Previously the
   keymaps lived in codecompanion's own lazy `keys` table, so no action could fire before
   `codecompanion.setup()` and therefore never before the hardened adapters existed. The keys now
   exist from startup regardless, so `bootstrap()` checks a `ready` flag set as setup's last
   statement and refuses the action otherwise.

Plus the packaging that is genuinely new: `plugin/` script, `health.lua`, `lazy.lua`, `pkg.json`,
`minimal.lua`.

## Findings worth not rediscovering

- **The write defence was silently disarmed** by the first `install_adapters`. Codecompanion's
  stock adapter entries are plain **strings** (`adapters.acp.claude_code == "claude_code"`, a
  pointer at its built-in module), so a guard asking "is something already here?" declined to
  install ours; `resolve("claude_code")` then returned the stock adapter with `timeout = 20000`, no
  `mode = dontAsk`, and `yolo` restored. Now: a string means "uncustomised, replace it", only a
  table or function is somebody's real definition. `tests/test_wiring.lua` asserts the resolved
  adapter is ours.
- **`nvim -l` never enters the main loop**, so `test_say`'s four `ui.confirm` cases died mid-run and
  the suite reported 13 of 17 while looking green. The runner uses `-c luafile … -c qa!`. Without
  this the "517" would have been a lie.
- **BSD `sed` has no `\b`** — the entire `Ai*` → `Ducktape*` rename silently did nothing until it
  was redone with `perl`. Also, **zsh does not word-split unquoted expansions**, so
  `sed -i '' … $FILES` passed the whole newline-joined list as one filename.
- **`hasmapto()` searches the *rhs*** of existing mappings (`:h hasmapto()`), so it answers "has the
  user already bound this action to a key of their own?", not "is this key taken?". `maparg` answers
  the second. Both are needed, or "their mapping wins" is a coin flip, since `plugin/` scripts run
  during `lazy.setup()` and a user's own `init.lua` mapping may land either side of it.
- **`_G.codecompanion_buffers` is created at the chat module's chunk level** (`interactions/chat/
  init.lua:347`), so health has to `require` that module before asking, or it reports a break that is
  only a cold start.
- **The markdown parsers are not bundled with Neovim 0.12.4.** They resolve to
  `~/.local/share/nvim/site/parser/*.so`, installed by nvim-treesitter. Hence nvim-treesitter is a
  hard dependency: without it the chat does not render and editing a sent message silently does
  nothing.
- **Do not create a `stylua.toml`.** There is none in the dotfiles and none globally; `conform` runs
  bare `stylua`, so the tree is at stylua's defaults (tabs, width 120). The rename lengthened
  identifiers enough to push some lines past 120, so `stylua lua/ tests/` was run once — a
  rename consequence, not a reformat.
- **codecompanion is Apache-2.0**, not MIT. Use its CI/Makefile as a reference to write our own; do
  not import its files. We copy none of its Lua, only call its API, so our MIT licence stands.
- Lua diagnostics reporting `Undefined global vim` throughout are the editor's `lua_ls` not having
  reloaded `.luarc.json`; the file is at the repo root and correct.

## Step 5 — docs, vimdoc, CI — done (`07a941c`)

- `docs/keymaps.md` rewritten against the real inventory. It had been stale against the *code*, not
  only the rename: no `<leader>cd`, `<leader>cL`, `<leader>cA`, `<leader>cR`; `<leader>cj`/`ck` and
  `g2`/`g3` listed as global when they are buffer-local; no `<C-x>` or help overlay in the chat-list
  section. Now carries the `<Plug>` names and the two config routes as well.
- `docs/how_to_use.md` and `docs/implementation.md` reconciled: branding renamed and the
  dotfiles-only citations reworded to state the finding. Two accuracy fixes found while in there —
  the chat default is `mode = "default"` not `acceptEdits`, and the `opencode-models.json` search
  order is XDG first and `~/.local/config` last. The module layout had never listed `pick.lua` or
  `reload.lua`.
- `README.md`: both install snippets, the dependency tables including the external programs, the
  two config routes, the provider-names ceiling, the `opencode-llm` contract, and the nvm trap.
- `Makefile` (`test`, `lint`, `fmt`, `doc`) and `scripts/vimdoc.md` as the panvimdoc source.
- CI: `ci.yml` (stylua, `lua-language-server --check`, suites on 0.11.4 / stable / nightly, which
  install the markdown parsers first), `release.yml` (release-please), and `docs.yml`.

**`doc/ducktape.txt` does not exist yet**, so `:h ducktape` — which `bootstrap()`'s error message
points at — will not resolve until either the docs workflow runs on a first push or someone with
pandoc runs `make doc`. pandoc is not installed on this machine and colima is not running, so
neither route was available. Nothing else depends on it.

## Step 6 — parity in a throwaway stowed config — done, swap reversed

The swap was made, everything below was run against it, and it has been **reversed**: `nvim/` is the
real package again, `nvim_main/` is gone, `~/.config/nvim` points where it did, and `:Lazy restore`
brought the plugin tree back to all 23 at their pinned commits. Verified afterwards: the statusline
segment is present, `<leader>cc`/`<leader>ci` are mapped from the lazy `keys` table, `ai.providers`
loads and reports `ollama gpt-oss:120b`. The only working-tree change is your own `lazy-lock.json`
edit, which predates this work.

To redo the swap:

```sh
cd ~/dotfiles
stow -D nvim && git mv nvim nvim_main && mkdir -p nvim/.config/nvim
# write the throwaway init.lua (see below), then
stow nvim
# reverse with: stow -D nvim && rm -rf nvim && git mv nvim_main nvim && stow nvim
#               nvim --headless "+Lazy! restore" +qa
```

**The throwaway config must set its own XDG roots**, in its own `init.lua`, before
`require("lazy")` — not in the launching shell. Stow does not cover `~/.local/share/nvim`, so a
plain `nvim` against a six-plugin spec makes lazy.nvim clean the real config's other seventeen. That
happened once here; `:Lazy restore` fixed it completely, but the config should never allow it.

While swapped, root `install.sh`'s `directories` array still says `nvim`, so running it would stow
the throwaway package.

### What was verified, all in the throwaway config

Scripts are committed at `~/projects/ducktape.nvim/tests/parity/`, with a README explaining each and
how to run them. `probe_init.lua` is the variant config; it takes a `$DT_VARIANT`.

| Check | Result |
|---|---|
| Load timing before any keypress | 49/49 — plugin script ran, all 17 `<leader>c*` and all 17 `<Plug>` maps exist, statusline segment injected with nvim's own default intact, `:Ducktape` present, and `codecompanion` / `ducktape.chat` / `ducktape.inline` / `ducktape.providers` all unloaded |
| First keypress wires everything | 38/38 — `bootstrap()` loads codecompanion, setup completes, claude resolves with `timeout = 90000` + `mode = dontAsk` + no `yolo` + empty env, opencode denies `edit`/`write`/`patch`, adapters claimed, send override is ours, `VimLeavePre` registered, provider defaults exact |
| Refuses when setup did not finish | 7/7 with no `extensions.ducktape`, 8/8 with a throw after the adapters went in. The second is the case an adapters-only check would wave through; a `validate` failure throws *before* them and leaves codecompanion's stock adapter, which is why refusing is the only defence |
| Keymap hedge | 5 variants, all clean: defaults, `keymaps = false`, `globals = false`, a user's own `<leader>ci` (maparg path), a user's own `<leader>zi` → `<Plug>` (hasmapto path). **This found the one real bug** (below) |
| Telescope absent | 11/11 — the chat list and both pickers name telescope and do not throw, the write defence and statusline are unaffected, health warns with the features named |
| catppuccin absent | all 17 `Ducktape*` highlight groups defined from the stand-in palette |
| `:checkhealth ducktape` | all green in the parity config; `vim.g.ducktape = { providers = … }` reported as being in the wrong table |
| `lazy.lua` dependency spec | naming ducktape alone pulls plenary, nvim-treesitter and telescope, and codecompanion stays unloaded — it is deliberately not a dependency |
| Live round trips | claude ACP: reply, real pid, session established, state `ready`. ollama HTTP: reply. opencode ACP: reply. Pool drains to zero on shutdown |
| Chat persistence | a new chat is written to `~/.local/state/dt-test/nvim/ducktape/chat_sessions.json` on exit with its provider and opts, read back on relaunch, and **no agent is spawned at startup** |

**The bug the parity run found, now fixed (`002aa75`):** `vim.g.ducktape = { keymaps = false }` created
the entire default set it asked to suppress. `plugin/ducktape.lua` reads `config.get()`, and the
`false` shorthand was only normalised in `config.setup()`. `keymaps = { globals = false }` worked,
which is why no suite caught it — they only ever went through the setup route. `tests/test_keys.lua`
now covers the `vim.g` route (577 assertions).

**Free-tier flakiness is not a regression.** opencode ACP intermittently answers
`503 The request queue is full` and ollama cloud occasionally times out after several back-to-back
calls. Both were A/B'd against the pre-extraction `lua/ai/` modules in the same nvim, with the same
adapters: opencode failed on the *original* code in the run where ducktape succeeded, and ollama
answered in 1s on both. Retry rather than debug.

### The interactive pass — also done, driven over RPC

`PLAN.md` verification §4 was run by driving a real nvim rather than by hand: a headless server with
`--listen`, keys sent with `--remote-send` so they go through the actual mapping layer, and state
read back with `--remote-expr`. Two things to know if it needs repeating: lazy.nvim rebuilds the
runtimepath, so a helper module has to be `dofile`d rather than added with `--cmd 'set rtp+='`; and
in the inline prompt the submit key is `<C-s>` in insert mode, `<CR>` only in normal mode.

| Flow | Result |
|---|---|
| `<leader>ci` from **visual mode** | prompt float titled ` Inline — ollama · gpt-oss:120b `, then in-flight mauve `DucktapeInlineRange` tint, spinner virt-line naming provider · model · instruction, and `AI 1↻` in the statusline |
| Line protection while in flight | `dd` on the held lines reverted with `put those lines back — <leader>cx cancels…`; `A` dropped straight back to normal mode; `u` refused with its own message; `u`/`U`/`<C-r>`/`g-`/`g+` all mapped buffer-locally |
| A request that fails | warm `DucktapeInlineWaiting` tint, `✖ ollama · failed · <instruction>` label, `AI 1✖`, and the reply kept rather than discarded |
| `<leader>cL` | list titled ` Inline — 1 to read ` with the failed row; `?` opens the help overlay, `?` again dismisses it and keeps the list, `q` closes the list |
| `<leader>cmi` | Telescope list of every provider · model with the cost labels and `▶ … current`; filtering to claude sonnet then `<CR>` shows the options float, and the selection is still ollama until `<CR>` confirms it — `inline → claude · sonnet effort=medium` |
| `<leader>cR` | prompt reopened pre-filled with the original instruction; submitting ran it on the new provider |
| Diff review | banner `g2 Accept \| g3 Reject \| <leader>cj/ck Hunk`, byte-identical to the original; `g2`/`g3`/`<leader>cj`/`<leader>ck` bound buffer-locally; **`{` and `}` not mapped**, so paragraph motion is intact; `<leader>cj` moved the cursor |
| `g2` / `g3` | accept made the change permanent and tore the maps down; reject restored the original exactly |
| One request per region | a second request overlapping a pending diff refused with `lines 1-10 has an inline diff waiting on you ("…") — g2 accepts it, g3 rejects it` |
| `<leader>cA` / `<leader>cX` / `<leader>cx` | `accepted 1 diff(s)`, `rejected 1 diff(s)`, and `cancelled 1 request(s)` against a genuinely running request |
| `<leader>cc` | chat opened with the winbar (`claude · opus │ title`) and the key footer; a real question answered |
| `<leader>cr` | renamed, pinned as `_ducktape_user_title`, winbar and buffer name followed |
| `<leader>cl` | Telescope list, `? help` on the border, row `▶ ● <title>  claude · opus` |
| `<leader>cs` | both scopes with the `(can‑read‑repo)` reach label; navigating to chat `Fast`, `<CR>` to edit, `l` to cycle `off → on`, `<CR>` to commit — and the **live ACP session** came back reporting `model_config on` |
| **The chat-edit fork** | rewrote the codeword in the sent transcript, asked again → `asking with your edited conversation`, a **new session id**, the title carried over, and the answer was the **edited** codeword rather than the one the original session remembered |
| `<leader>cn` / `<leader>ca` from visual mode | new chat created; action palette opened. Both callbacks are identical to the originals, which also ignore the selection |
| `<leader>cd` / `<leader>cq` | delete asked `Close …? It has no saved transcript.` and reported `deleted …`; close-all reported `closed 1 chat(s)` |
| `<leader>cI` on ollama | refused, naming the transport that cannot read the repo |
| `:Ducktape` | `pool` shows the live connection with age/idle/session; `send` with no args prints its usage; a bad subcommand prints `usage: :Ducktape {pool\|send}`; completion offers `pool send` |

`vim.fn.confirm()` returns its default immediately without a TTY, so the confirm prompts cannot be
answered headlessly — the delete path was driven past it with `ui.confirm` stubbed. The prompt itself
is covered by `test_say`.

### Two more defects found, both fixed (`8939354`)

- **Two messages named a key that does not exist.** The deep-transport refusals said "Switch with
  `<leader>cm`" — a prefix, bound to nothing, so pressing it just waits for a third character. They
  now name `<leader>cmi` through `keys.lua`, so a remap carries into them. The originals had the same
  imprecision; this is the one message change that is a correction rather than a rename.
- **A `:map` description still said `ai:`** — `ai: held off while an inline request runs`, on the
  undo-lock mappings. The rename's exit-gate grep should have caught it and did not; the gate has
  been re-run over `lua/ plugin/ tests/ README.md scripts/` and is clean.

### The move really is a move, checked mechanically

Reversing the rename on every moved module (`ducktape` → `ai`) and diffing against
`nvim_main/.config/nvim/lua/ai/`, with the originals run through the same stylua, leaves only the
three sanctioned edit kinds:

- `statusline.lua`, `acp_pool.lua`, `pick.lua`, `reload.lua`, `inline/{acp,parse,http}.lua` — **zero**
  differing lines
- `chat.lua`, `inline/init.lua`, `chat_list.lua`, `inline/list.lua` — the `FOOTER_TIERS`/`HELP`
  constants becoming functions, the `K()` key lookups, the `_ducktape_*` field renames, and stylua
  reflow where the longer identifiers crossed 120 columns
- `providers.lua` — the lazy `state` plus `apply()`, and `models_json` read from config
- `inline/relay.lua` — the relay command read from config
- `debug.lua` — the two user commands becoming `:Ducktape` subcommands

Nothing outside those. The script for this is worth keeping in mind if the plugin is ever re-synced.

## Step 9 — the dotfiles switch — done

Executed on the machine's real config, not a throwaway swap (step 8 already proved parity once).
The daily driver now points at the plugin: `lua/plugins/codecompanion.lua` is the two sibling
specs, `lua/ai/` is deleted, `lua/config/options.lua`'s statusline block is gone, state directories
are merged. Details are in the "Dotfiles state" section above.

Two things `PLAN.md`'s own step-9 recipe got right, confirmed still true here:

- **Keep `event = "VeryLazy"` on codecompanion.** Dropping it makes it a start plugin loaded
  synchronously at startup (`lazy/core/plugin.lua:235-242`, and `config/lazy.lua` never sets
  `defaults.lazy`). `ducktape` is the one that wants `lazy = false`.
- The state directory needs a one-time move so open chats and titles carry over.

Two things the recipe didn't anticipate, found while actually executing it:

- **The move is a merge, not a `mv`.** `~/.local/state/nvim/ducktape/` already existed with real
  content (`models.json`) from earlier testing, so a plain `mv ~/.local/state/nvim/ai
  ~/.local/state/nvim/ducktape` would have nested `ai/` inside the existing `ducktape/` directory
  instead of merging into it. Copy the two files in and remove the source instead.
- **`dev.fallback = true` is required, not optional**, for the local-else-GitHub portability this
  switch was built for. `lazy/core/meta.lua`'s `dev.patterns` matching forces `plugin.dir` to the
  local dev path unconditionally when `fallback` is left at its default `false` — even when that
  path doesn't exist. This is why the switch used `dev.path`/`dev.patterns` instead of this doc's
  own hardcoded-`dir=` recipe: the hardcoded form only ever works on a machine with that exact
  local checkout, while `dev` + `fallback = true` falls through to a normal GitHub clone elsewhere.
