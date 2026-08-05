# Extract the CodeCompanion layer into `ducktape.nvim`

## What the plugin does — the full inventory

Nothing in this list is optional or "nice to keep". It is what exists today, and all of it moves. Anything absent from this table after the move is a regression.

**Global keymaps — all 17, exactly as they are** (`plugins/codecompanion.lua:36-161`):

| Key | Modes | Action |
|---|---|---|
| `<leader>cc` | n | toggle the last chat, reopening it after a restart |
| `<leader>cn` | n, x | new chat on the current provider and options |
| `<leader>cq` | n | close every chat |
| `<leader>cr` | n | rename the current chat |
| `<leader>cd` | n | delete the current chat and its saved transcript |
| `<leader>cl` | n | chat list — live chats plus every resumable session for the repo |
| `<leader>ca` | n, x | codecompanion's action palette |
| `<leader>ci` | n, x | inline prompt, no tools, no repo reads |
| `<leader>cI` | n, x | inline prompt that may read the repo (ACP only) |
| `<leader>cL` | n | inline list — in flight plus waiting for review |
| `<leader>cA` | n | accept every inline diff in this buffer |
| `<leader>cR` | n | ask again about the inline edit under the cursor |
| `<leader>cx` | n | cancel the inline request under the cursor, or stop the chat agent |
| `<leader>cX` | n | cancel every inline request in this buffer |
| `<leader>cmi` | n | switch the inline backend / model |
| `<leader>cmc` | n | switch the chat backend / model |
| `<leader>cs` | n | status panel |

**Buffer-local, on a pending inline diff** (`inline/init.lua:409-432`, torn down with the diff): `g2` accept, `g3` reject, `<leader>cj` / `<leader>ck` next / previous hunk, and the banner that names them. Plus the deletion of codecompanion's own `{` / `}` hunk maps so paragraph motion keeps working (`:397-408`).

**Chat buffer:** `<CR>` / `<C-s>` send — **ours**, overriding only the callback so an edited transcript is carried; everything else there is codecompanion's own and keeps working (`ga`, `gd`, `gf`, `gc`, `gr`, `gs`, `gx`, `gy`, `gR`, `gM`, `gm`, `gba`, `gbd`, `gtx`, `gty`, `gS`, `{`, `}`, `[[`, `]]`, `?`, `q`, `<C-c>`). Ours adds the winbar (provider · model · title) and the statusline footer that lists the keys.

**Chat list** (`chat_list.lua`): `<CR>` focus a live chat or restore a session, `<C-d>` close a live chat or drop a pending one leaving the session intact, `<C-x>` delete for good including the agent's own transcript, `<C-r>` / `r` rename in a way that survives reopening, `?` / `<C-/>` / `<C-_>` a help overlay, `<Esc>` / `q` / `<C-c>` dismiss.

**Provider/model picker** (`pick.lua`, used by both `<leader>cmi` and `<leader>cmc`): `j`/`k`/`<Down>`/`<Up>` move, `l`/`h`/`<Tab>`/`<S-Tab>` cycle an option's value, `<CR>` confirm, `q`/`<Esc>` discard — a float, so the whole selection is confirmed as one change rather than applied per keystroke.

**Behaviour behind those keys:**

- **Inline editing** — several requests in flight at once across buffers, each holding its lines against clobbering (and against undo) until it settles; diffs applied per region; replies that are prose rather than code kept and readable instead of discarded; retry and take-into-chat from the list.
- **Chat** — sessions that survive an nvim restart with nothing respawned until you open one; restore any past session for the repo; user-chosen titles that outlive the agent's own auto-titles; per-chat provider, model, effort, mode and agent; and editing a message you already sent, where asking again forks a fresh agent session carrying your edited transcript.
- **Three providers, one option UX** — claude and opencode over ACP, ollama over HTTP (local or cloud); model lists resolved live and cached; free-tier-first defaults; a label at the point of choice saying what a model draws on; a tool-free relay path for opencode.
- **Write defence** — inline transports cannot write (claude runs `mode = dontAsk`, opencode gets an explicit deny set, and a connection that did not take the mode is not used); chat may write but asks first; buffers reload themselves when the agent edits a file underneath them, and refuse to when you have unsaved changes.
- **Status and plumbing** — the status panel with live per-session option changes; statusline counters for running / waiting / failed inline requests; a pooled ACP connection layer with reuse, overflow and idle teardown; `:Ducktape pool` and `:Ducktape send` for debugging.

`nvim/_nvim_ai/keymaps.md` is **stale** against this list — it documents `<leader>cj`/`ck` and `g2`/`g3` as global and is missing `<leader>cd`, `<leader>cL`, `<leader>cA` and `<leader>cR` entirely, and its chat-list section omits `<C-x>` and the help overlay. Reconciling it against the table above is part of step 7, and it is the one doc edit that is not a straight copy.

## Ground rule: this is a move, not a rewrite

**The 17 modules under `nvim/.config/nvim/lua/ai/` are already what we want. They get copied, not rebuilt.** Every line of behaviour in them was arrived at by measurement — the transport reach table, the `mode = dontAsk` write defence, the ΔE-checked highlight hues, the header-line realignment, the pool's overflow and idle rules — and none of that reasoning gets re-derived. If a design decision in the existing code looks odd, the answer is to read its comment, not to improve it.

The diff on the moved files should be reviewable as **essentially a rename**. Only three kinds of edit to them are sanctioned:

1. **The rename** — namespace, highlight/augroup names, message prefixes, state paths, the four non-literal module references (step 2).
2. **Reading `providers`/`defaults`/`adapters`/`keymaps` from config** instead of module-level literals — and the shipped defaults must be the current values *verbatim*, so an empty `opts` produces byte-identical behaviour. This is the configurability you asked for; it is not licence to restructure the modules that read it.
3. **The bootstrap contract** (step 5) — which exists *only* to restore an invariant the move itself breaks. Today no action can fire before `codecompanion.setup()`; moving the keymaps out of codecompanion's `keys` table removes that guarantee, and `bootstrap()` puts it back. It adds no capability.

Everything else the plan describes — `lazy.lua`, `pkg.json`, `plugin/ducktape.lua`, `health.lua`, `minimal.lua`, `doc/`, CI, the release workflow — is **new files placed around the moved code**, not changes to it. That is the packaging that makes it installable; it is the only genuinely new work here.

Explicitly **not** in scope, however tempting while the files are open: refactoring the provider-name hardcoding into a registry; porting the test suites to busted or mini.test; redesigning any UI; touching the wording of a single user-facing message; fixing the two known bugs (`relative_time`, the footer-colour check); "tidying" module boundaries or comment style. A change that is not (1), (2) or (3) above, or a new file, does not belong in this work.

### Copy-paste by default — where each file actually comes from

"New file" oversells most of the packaging. Almost all of it is lifted from something that already works, here or in codecompanion's own repo. Write from scratch only what is in the last column.

| Destination | Copied verbatim from | Genuinely new |
|---|---|---|
| `lua/ducktape/*.lua` (17 modules) | `lua/ai/*.lua` | nothing — rename only |
| `lua/ducktape/config.lua` | the `M.providers` / `M.defaults` tables out of `providers.lua:10-99`, and the adapter definitions out of `plugins/codecompanion.lua:6-29,187-244`, **unchanged as data** | a `vim.tbl_deep_extend` + `vim.validate` wrapper, ~30 lines |
| `lua/ducktape/keys.lua` | the 17 entries of the `keys` table in `plugins/codecompanion.lua:36-161` — same lhs, modes, descriptions, callbacks | `lhs()` / `label()` lookups, ~20 lines |
| `plugin/ducktape.lua` | those same 17 entries; the statusline injection from `config/options.lua:98-107`; the guard shape from `codecompanion.nvim/plugin/codecompanion.lua` | the `<Plug>` layer, the two skip checks, `bootstrap()`, `:Ducktape` |
| `lua/codecompanion/_extensions/ducktape/init.lua` | the shape from `codecompanion.nvim/doc/extending/extensions.md` | ~10 lines |
| `lua/ducktape/health.lua` | `codecompanion.nvim/lua/codecompanion/health.lua` — same `vim.health` helper preamble, same deps/parsers/libraries table pattern | the entries themselves |
| `tests/*` | the 9 rescued suites, harness included | `run_tests.sh`, `minimal_init.lua` |
| `minimal.lua` | `codecompanion.nvim/minimal.lua` | the spec block |
| `Makefile`, `.luarc.json`, `.github/workflows/{ci,release}.yml` | codecompanion.nvim's own as the *model* — same toolchain (panvimdoc target, stylua invocation, nvim version matrix, release-please). Note it is **Apache-2.0**, not MIT, so use it as a reference and write our own three-line equivalents rather than importing files; we copy none of its Lua, only call its API, so our repo's own licence stays a free choice | paths and names |
| `stylua.toml` | **nothing — do not create one.** There is no stylua config in the dotfiles and none globally; `conform` (`lua/plugins/lsp.lua:189`) runs bare `stylua`, so the existing 9,145 lines are formatted to stylua's *defaults* (tabs, width 120). Adding a config with any other setting reformats the entire tree on the first run and destroys the "diff is a rename" property this whole ground rule exists to protect | nothing |
| `docs/*.md` | `nvim/_nvim_ai/{how_to_use,implementation,keymaps}.md` | nothing |
| `README.md`, `lazy.lua`, `pkg.json` | — | all three, and they are small |
| the step-8 test config | `config/lazy.lua`'s bootstrap block, cut down | the plugin list |

Two places where "no thinking" is the wrong instinct and the plan says so deliberately: the **bootstrap contract** (step 5) and the **two keymap skip checks** (step 6). Both exist because the move changes *when* code runs, and both were arrived at by finding real failures — a disarmed write defence and a coin-flip keymap clobber. Everything else: copy it.

## Context

`nvim/.config/nvim/lua/ai/` is a 9,145-line layer on top of codecompanion.nvim: a connection pool, an inline-edit engine with its own diff/queue/list UI, a chat manager with session persistence and restore, a provider/model picker, a status panel, a statusline segment, and the edited-history fork. It is only reachable by someone who clones these dotfiles wholesale. The goal is a standalone plugin colleagues can install and update with `:Lazy`, behaving **exactly** as the current setup does — same keys, same messages, same defaults — with no feature added or dropped in the move.

Name chosen: **`ducktape.nvim`**, Lua namespace `ducktape`.

## What "the standard way" is (answer to the open question)

Verified against the **official Neovim reference manual** shipped with your 0.12.4 — `:h lua-plugin` (353 lines, the canonical plugin-authoring guide), `:h health-dev`, `:h pack.txt` — not just a third-party opinion piece. The official doc turns out to be more specific than the community guide on three points, and two of them change the plan.

| Official rule (`:h lua-plugin`) | Applied |
|---|---|
| `lua-plugin-lazy`: "Plugins should arrange their 'lazy' behavior once, instead of expecting every user to micromanage it" — via a small `plugin/<name>.lua` defining commands and mappings that does **not** eagerly `require()`. Explicitly: there is **no performance benefit** to a user declaring `keys`/`event` in their plugin manager instead. | **Changes today's design, with one lazy.nvim-specific twist.** The 17 `<leader>c*` maps currently live in lazy's `keys` table; they move into `plugin/ducktape.lua`, each with its `require()` inside the callback, so colleagues need no `keys` in their spec. The twist: lazy.nvim only sources a plugin's `plugin/` files when it *loads* the plugin (`lazy/core/loader.lua`, `M.packadd`), so **ducktape must be `lazy = false`** for its maps to exist at startup. That is fine — the file is maps, a command and a string append, no `require` of the core. The heavy deferral stays with **codecompanion, which keeps `event = "VeryLazy"`**; pressing a ducktape key `require`s a ducktape module, which `require`s codecompanion, and lazy.nvim's `package.loaders` hook (`lazy/init.lua:83` → `Loader.auto_load`) loads codecompanion and runs its `config` right then. That reproduces today's "first keypress or VeryLazy, whichever comes first" exactly. See the warning in step 9 — *dropping* `event` is what would break this. |
| `lua-plugin-keymaps`: "Avoid creating excessive keymaps automatically." Buffer-local maps for a filetype or floating window are called "uncontroversial". Recommends `<Plug>` mappings, and notes you can "detect user-defined mappings through `hasmapto()` before creating defaults". | Ship `<Plug>(Ducktape…)` for all 17 actions **and** the `<leader>c*` defaults, each skipped when the user has already claimed that action or that key (two different checks — see step 6), plus `keymaps = false` to opt out wholesale. Behaviour on this machine is unchanged — nothing else maps those keys. The chat-buffer and inline-diff maps are the "uncontroversial" buffer-local kind and stay as they are. |
| `lua-plugin-init`: prefers a `setup(opts)` that "only overrides the default configuration and does not contain any initialization logic", with init in a `plugin/` script — but explicitly permits combining them for "customizing complex initialization, where there is a significant risk of misconfiguration" and for "functionality that should not be initialized automatically". | Both exemptions apply here (agent subprocesses; a write-permission defence), but we still split: `config.lua` is pure merge+validate, initialization happens in the extension entry point and `plugin/ducktape.lua`. |
| `lua-plugin-config`: validate merged config with `vim.validate()`; unknown-field/typo detection "may be better suited for a **health** check, to reduce overhead". | **Corrects my first draft**, which put typo detection in setup. Types via `vim.validate` at setup; unknown-key detection moves to `health.lua`. |
| `health-dev`: a `lua/{plugin}/health.lua` module returning a table with a **`check()`** function; `:checkhealth` finds it automatically. `lua-plugin-troubleshooting` also asks for a **minimal config template** for issue reproduction. | `lua/ducktape/health.lua` exposing `M.check()`, plus a committed `minimal.lua` (codecompanion ships one too). |
| `lua-plugin-versioning`: SemVer tags and releases, automated in CI; names `release-please-action`. `lua-plugin-type-safety`: LuaCATS + lua-language-server in CI. `lua-plugin-doc`: vimdoc via panvimdoc so `:h ducktape` works. | All adopted. luarocks skipped — the doc recommends it mainly for plugins with build steps or that others depend on. |
| `lua-plugin-ui`: for plugin-owned UI buffers, consider exposing actions as code-actions via an in-process LSP so `gra` lists them. | Noted, out of scope — it would *add* a surface, and the brief is exact parity. |

**Not covered by the official docs, and worth stating plainly:** the extension mechanism is codecompanion's own convention, not a Neovim standard. It is still the right host integration — codecompanion resolves `codecompanion._extensions.<name>` off the runtimepath and loads it at the end of its `setup()` (`lua/codecompanion/init.lua:556`), and its authoring guide (`doc/extending/extensions.md`) explicitly blesses mutating `require("codecompanion.config").interactions.chat.keymaps` from inside `Extension.setup(opts)`, which is exactly how our `send` override is installed today. `codecompanion-history.nvim`, the flagship extension, is laid out this way and installed as a **dependency of codecompanion.nvim** with `extensions = { history = { opts = … } }`. Colleagues will recognise the shape.

**One deliberate deviation:** the official doc discourages shipping default global keymaps at all. We ship them anyway — the `<leader>c*` set *is* the product and parity is the brief — but hedged three ways (`<Plug>` maps, `hasmapto()` guards, `keymaps = false`), which is as close to compliant as a keymap-shaped plugin gets.

### Updates: `:Lazy`, and `vim.pack` too

Any git repo updates fine on a branch; **tags** buy the stable channel, and on 0.12 they buy more — `:h pack.txt` states plugins "should be Git repositories with versions as named tags following semver", because `vim.pack`'s `version = vim.version.range('1.0')` resolves the greatest matching semver tag. One tagging scheme therefore serves both managers:

- **lazy.nvim**: `version = "*"` (latest tag) or track `main`; `lazy-lock.json` pins the commit, `:Lazy update` / `:Lazy restore` as usual.
- **built-in `vim.pack`** (your nvim is 0.12.4, so colleagues may skip lazy entirely): `vim.pack.add({ { src = …, version = vim.version.range('1.0') } })`, updated with `vim.pack.update()`, its own lockfile.

Mechanism, following codecompanion: conventional commits on `main` → `release-please-action` opens the release PR → merging it tags `vX.Y.Z`. README shows both install snippets. Because this code calls codecompanion internals, the README states a **minimum codecompanion version** and `health.lua` checks it — a cc bump is the realistic breakage source, not us. The full internal surface to re-check on every bump: `interactions.chat` (`buf_get_chat`, `last_chat`), `interactions.chat.parser` (`messages`, `headers`), `interactions.chat.helpers.format_role`, `interactions.chat.acp.{commands.link_buffer_to_session, render.restore_session, defaults}`, `interactions.shared.input`, `diff.keymaps` (the accept/reject callbacks), `config.interactions.shared.keymaps.{next_hunk,previous_hunk}` (read at `inline/init.lua:397-403` to delete cc's own hunk maps buffer-locally — the read is *outside* the `pcall`, so a missing key throws rather than degrades, though `:405-408` already deletes the literal `{`/`}` as a fallback for exactly that case), `config.interactions.chat.opts.blank_prompt`, `acp`, `adapters`, `http`, `helpers`, `utils.async`. Plus the `Chat` object's own surface, which is the most fragile part and all read without a `pcall`: `Chat:add_callback` (`chat.lua:402`, the `on_ready` hook that keeps the chat-edit baseline in step), `Chat:add_message` (`chat_edit.lua:246,251`, how a forked transcript is injected), and the fields `chat.header_line`, `chat.current_request`, `chat:submit()` (`chat_edit.lua:275-298`). And the least defensible of the lot: **`_G.codecompanion_buffers`**, codecompanion's private bookkeeping global (created and pruned in `interactions/chat/init.lua:347,610,1777-1779`, documented nowhere), read at 6 sites — `chat.lua:533,633,785,996`, `chat_list.lua:97,230` — as the way to enumerate every open chat. It is how `newest_chat`, `save_open_chats`, `connection_for_cleanup` and the chat list find their buffers. A cc refactor renaming it takes out the chat list silently, so the health check should assert the global exists and is a table rather than only checking the version floor.

## Dependency verdict

The plugin **declares** these itself rather than leaving them to a README a colleague may not read. Four mechanisms, each doing a different job:

1. **`lazy.lua` at the plugin root** — lazy.nvim reads a plugin-provided spec from there by default (`lua/lazy/pkg/lazy.lua`, and `pkg.sources` is `{"lazy", "rockspec", "packspec"}` with `pkg.enabled = true` in `lazy/core/config.lua:49-57`). It carries `lazy = false` and `dependencies = { plenary, nvim-treesitter, telescope }`, so a colleague writes `{ "you/ducktape.nvim" }` and gets the tree.
   **Codecompanion stays out of that `dependencies` list**, deliberately. `plugin.lazy = plugin._.dep or …` (`lazy/core/plugin.lua:235-242`) plus `M.load` loading a plugin's dependencies before the plugin itself means anything listed as a dependency of a `lazy = false` plugin loads eagerly at startup — which is precisely the trap step 9 warns about. Codecompanion belongs in the user's own spec, where its `event = "VeryLazy"` and `extensions.ducktape` opts live. Whether a plugin-provided `lazy.lua` may return *sibling* spec entries (and so ship that codecompanion entry too) is worth one probe before relying on it.
2. **`pkg.json`** — the same dependency map in packspec form, for managers that read it.
3. **`lua/ducktape/health.lua`** — the runtime source of truth: every dependency below, marked required or optional, with the specific feature named when an optional one is missing, plus the external binaries and env vars, which no manifest can install.
4. **`plugin/ducktape.lua`** — refuses with one clear message rather than a stack trace when Neovim is too old or codecompanion is absent.

`vim.pack` has no dependency field at all (`:h pack.txt`), so for that install path the README's list is the only mechanism — one more reason the README table has to be complete and not a courtesy.

| Dependency | Verdict |
|---|---|
| codecompanion.nvim | **Hard.** Not vendored — the colleague declares both, as two sibling spec entries (step 9 has the exact recipe): ducktape `lazy = false`, codecompanion `event = "VeryLazy"` with ducktape enabled in its `extensions`. Not as a `dependencies` chain: ducktape's `plugin/` file must be sourced at startup, and a dependency of a lazy parent is not. Uses internal APIs → min-version pin + health check that resolves them. |
| plenary.nvim | **Required**, codecompanion's own declared dep (`codecompanion/health.lua` `M.deps`). Declared in `lazy.lua` too, since a `vim.pack` user gets nothing transitively. |
| nvim-treesitter | **Required, and the one that is easy to miss.** Neovim 0.12.4 ships no `markdown`/`markdown_inline` parser — on this machine both resolve to `~/.local/share/nvim/site/parser/*.so`, installed by nvim-treesitter. Codecompanion's own health check demands them, and `chat_edit.lua`'s `transcript()` parses the chat buffer with the `markdown` `chat` query, so message editing silently does nothing without it. |
| telescope.nvim | **Optional at runtime, required for three features.** The chat list and both model pickers need it; all three already `pcall(require, "telescope")` and report a clear error (`chat_list.lua:568`, `pick.lua:468`). Declared in `lazy.lua`, named in health. |
| catppuccin | **Optional.** `ui.ensure_highlights()` already falls back to a hardcoded teal palette (`ui.lua:546`). Unchanged. |
| External CLIs | Prerequisites, documented and health-checked, never installed by us: `node` + `claude-agent-acp` (claude), `opencode` (opencode ACP + model list), `curl` + `$OLLAMA_API_KEY` (ollama cloud), local ollama (ollama local), and `git` — `chat_list.lua:28` shells out to `git rev-parse --show-toplevel` to scope resumable sessions to the repo, degrading to "no resumable sessions" without it. |
| `opencode-llm` | **The one gap.** The tool-free opencode inline path shells out to a bash script that lives in *these dotfiles* (`claude/.local/scripts/opencode-llm`, 187 lines, needs `jq` and an opencode `relay` agent). Not vendored — vendoring makes two copies that drift, and that script is used by Claude Code skills unrelated to nvim. Instead: make the command configurable (`opts.opencode.relay.cmd`, default `"opencode-llm"`), document its contract (stdin = content, args = prompt, stdout = answer, exit codes 1/2/3/5/6/124 — already enumerated in `inline/relay.lua:18`), and health-check it. Colleagues without it get today's exact error, `"opencode-llm is not on PATH"`; claude and ollama are unaffected. |

## Where the source lives

New standalone repo at `~/projects/ducktape.nvim`, pushed to GitHub. Dotfiles consume it during development through lazy.nvim's `dir = vim.fn.expand("~/projects/ducktape.nvim")` (with `lazy = false`, per step 9), so there is one editable copy and no drift. `nvim/.config/nvim/lua/ai/` is deleted from dotfiles only after parity is verified — and parity is verified in a throwaway stowed config (step 8), never by modifying the working one.

## Repo skeleton

```
ducktape.nvim/
  lua/ducktape/            <- the 17 modules, renamed from lua/ai/
    init.lua               <- setup(opts), the only public entry
    config.lua             <- defaults + vim.validate, new
    keys.lua               <- resolved keymaps + label lookup, new
    health.lua             <- :checkhealth ducktape, new
    acp_pool.lua chat.lua chat_edit.lua chat_list.lua debug.lua
    pick.lua providers.lua reload.lua status.lua statusline.lua ui.lua
    inline/{init,acp,http,list,parse,relay}.lua
  lua/codecompanion/_extensions/ducktape/init.lua   <- thin: opts -> require("ducktape").setup
  plugin/ducktape.lua      <- loaded guard, nvim-0.11 check, <Plug> maps,
                              default keymaps, :Ducktape command — no eager require
  doc/ducktape.txt         <- panvimdoc output, committed
  docs/                    <- how_to_use.md, implementation.md, keymaps.md (sources)
  tests/                   <- the 9 suites + minimal_init.lua + run_tests.sh
  lazy.lua                 <- plugin-provided spec: lazy = false + dependencies
  pkg.json                 <- same dependency map, packspec form
  minimal.lua              <- repro template (:h lua-plugin-troubleshooting)
  .github/workflows/       <- ci.yml (nvim 0.11/0.12/nightly), release.yml (release-please)
  .luarc.json stylua.toml .gitignore LICENSE README.md Makefile
```

## Steps

### 1. Rescue the tests first

The 9 suites (517 assertions) exist **only** in the session scratchpad `/private/tmp/claude-502/-Users-adriansanchezalbanell-dotfiles/6f7a0259-*/scratchpad/`, which gets wiped: `test_capture` 22, `test_inline_guard` 101, `test_inline_list_edges` 76, `test_inline_list` 43, `test_say` 17, `test_settle_all` 74, `test_shift` 18, `test_waiting` 84, `test_chat_edit` 82. Copy all nine plus the useful probes (`probe_header`, `probe_http_payload`, `probe_wiring`, `probe_footer`, `probe_empty_list`, `cleanup_probes`) to `~/projects/ducktape-tests-rescue/` before anything else — that directory, not the repo, because step 2 is what creates the repo, and the scratchpad may not survive until then. They move to `tests/` as step 2's first act. They are bespoke headless-nvim scripts with their own `check()` harness — keep the harness as it is and add `tests/run_tests.sh` to run each under `nvim --headless -u tests/minimal_init.lua -l <file>` and aggregate. Porting to busted is a separate, later exercise; the guide prefers busted but a rewrite here would trade the only regression net for style points.

**The suites are inside the rename's scope, not outside it.** They carry ~34 `require("ai.…")` calls of their own (`test_chat_edit.lua:16-18`, `test_capture.lua:49,52`, and so on), so step 2's rename must run over `tests/` as well as `lua/`. Miss that and every suite dies on its first `require` — 0 of 517 assertions execute, and the regression net is gone before parity work starts. So: **run the suites green against the renamed tree before touching anything else**, and treat that as step 2's exit condition rather than a verification-phase afterthought.

### 2. Bootstrap the repo, copy, rename

`git init`, MIT LICENSE, `.luarc.json` with `"runtime.version": "Lua 5.1"`, `stylua.toml` copied from this repo's nvim settings (tabs, 120 cols — keep it identical so the diff stays reviewable). **Then move `~/projects/ducktape-tests-rescue/*` into `tests/`** — the copy step 1 deferred, and the thing that must not be forgotten, since the rename below has to cover it.

The rename is mechanical and scriptable, then reviewed by hand:

| From | To | Sites |
|---|---|---|
| `require("ai.` | `require("ducktape.` | 76 |
| `lua/ai/` | `lua/ducktape/` | dir move |
| `_ai_provider/_ai_model/_ai_opts/_ai_resumable/_ai_user_title` | `_ducktape_*` | 33 |
| `Ai*` highlight groups + augroups (`AiWinBar*`, `AiFooter*`, `AiInline*`, `AiList*`, `AiChatSpinner`, `AiChatPersistence`, `AiChatWinbar<n>`, `AiInlineBuf<n>`, `AiAcpPool`, `AiBufferReload`) | `Ducktape*` | 99 (100 counting the `AiPickSettings` namespace on the row below) |
| `[ai]` message prefix | `[ducktape]` | 97 |
| the other two prefixes: `[ai.pool] ` and `[ai (inline)] ` | `[ducktape.pool]`, `[ducktape (inline)]` | `acp_pool.lua:35`, `inline/init.lua:1774,1796` |
| old command names inside strings | `:Ducktape send` | `debug.lua:115` (scratch title), `:135` (usage text) |
| buffer var `ai_chat_spinner` | `ducktape_chat_spinner` | `chat.lua:126,137,140,667,670` |
| LuaCATS `---@class ai.parse.*` | `ducktape.parse.*` | `inline/parse.lua:11,15`, `inline/init.lua:1094`, `parse.lua:312-313` |
| `stdpath("state").."/ai/"` | `.."/ducktape/"` | 2 (`chat.lua:329,747`) |
| `:AiPoolStatus`, `:AiDebugSend` | `:Ducktape pool`, `:Ducktape send` | `debug.lua:127,131` |
| namespaces: `AiPickSettings`, `AiInlineList`, `ai_inline_anchor`, `ai_ui`, `ai_help` | `Ducktape…` / `ducktape_…` | `pick.lua:289`, `inline/list.lua:138`, `inline/init.lua:19`, `ui.lua:13,441` |
| **module paths that are not `require("ai.` literals** — see below | — | 4 sites |

**The rename table above is a `require("ai.` text substitution, and four module references do not look like that.** Each is load-bearing, and a mechanical pass sails straight past all four:

- `inline/init.lua:1351-1353` builds the transport module name as a *string* — `"ai.inline.http"` / `"ai.inline.relay"` / `"ai.inline.acp"` — and `require(module)` at `:1366` is the dispatch point for **every** inline request. Unrenamed, `<leader>ci` and `<leader>cI` fail on the first keypress with "module not found".
- `statusline.lua:27` reads `package.loaded["ai.inline"]`. Unrenamed it is always `nil`, so the segment silently renders `""` forever — the failure mode that shows nothing rather than erroring.
- `config/options.lua:99` embeds the path inside a statusline expression, `"%{%v:lua.require'ai.statusline'.render()%}"` (single quotes, no parens), and `:101` guards re-injection with `current:find("ai.statusline", 1, true)`. Both strings move to `plugin/ducktape.lua`; the plan's "moved as-is" means *relocated*, not *unedited* — the path and the guard needle both change, and if only one does, the guard stops matching and every reload appends a second copy of the segment.

`test_waiting.lua:503-508` asserts `statusline.render()` shows `1↻`/`1◆` against a live `package.loaded["ai.inline"]`, so the suite does catch the `statusline.lua:27` case — but only once step 1's test rename is done. Nothing in the suite covers the transport dispatch, so that one needs the manual inline pass in verification §4.

**Exit gate for this step — do not trust the table above to be complete.** Three separate review passes each found another category it had missed (`[ai (inline)]` inside chat message content, `AiDebugSend` in a usage string, a `ai_chat_spinner` buffer var, five namespaces, four string-built module paths). Enumeration is the wrong instrument. After the rename, this must come back with nothing but deliberate matches:

```sh
# case-sensitive on purpose: -i would fold \bAi[A-Z] into "aid/aim/air/aisle"
grep -rnE '\bai\b|\[ai|"ai\.|'"'"'ai\.|_ai_|\bAi[A-Z]|\bai_[a-z]' lua/ tests/ plugin/ doc/ README.md
```

Every hit is either renamed or consciously kept (prose about "AI" in comments and docs is fine, and `codecompanion` names obviously stay). Two hits that must **not** be renamed: the string `"claude_code"`/`"opencode"`/`"ollama"` adapter names, and anything under `require("codecompanion…")`.

Two further content edits while renaming: the 11 comments citing dotfiles-only docs (`_codecompanion/findings.md`, `AGENTS.md`, `MODELS.md`, and the numbered work-packet steps — `providers.lua:9,60,76,236,259,260,264,388`, `inline/init.lua:1283`, `debug.lua:5`, and `plugins/codecompanion.lua:222`, which travels into the adapter data) get reworded to state the finding instead of the file; and the `providers.lua:313-315` `opencode-models.json` search path becomes configurable with the same three paths as defaults.

The two debug commands collapse into one `:Ducktape` with subcommand completion (`pool`, `send {provider} {prompt}`), declared in `plugin/ducktape.lua` with the `require()` inside the callback per `lua-plugin-defer-require`. This is the only intentional behavioural difference in the whole move, and it is forced anyway — the old names had to change.

### 3. `config.lua` — the new configuration surface

Defaults are today's values verbatim, so an empty `opts` reproduces the current setup exactly. Deep-merged over, then type-checked with `vim.validate()`. Unknown-key detection lives in `health.lua`, not here, per `lua-plugin-config`.

**Config arrives by two routes, and which one depends on when the value is needed.** `plugin/ducktape.lua` runs before lazy has applied any `opts`, so anything that file acts on cannot come from `setup()`:

| Route | Fields | Read at |
|---|---|---|
| `vim.g.ducktape` | `keymaps`, `statusline` | `plugin/` script time, i.e. startup |
| extension `opts` | everything else — `providers`, `defaults`, `adapters`, `opencode`, `codecompanion` | `codecompanion.setup()` time |

`keymaps` may also arrive a second time through extension `opts`, as a late override that re-creates the maps. `vim.g.ducktape` unset means today's defaults. Because it bypasses `config.lua`'s `vim.validate()` entirely, `health.lua` validates *its* shape too — otherwise `vim.g.ducktape = { keymaps = flase }` misbehaves with nothing anywhere reporting it. The bullets below say which route each field takes.

- `providers` / `defaults` — lifted straight out of `providers.lua:21-99` (the provider specs, and the inline/chat default provider + per-provider opts: ollama `gpt-oss:120b` cloud, claude `opus`/`xhigh`/`mode=default`, opencode `auto`). `providers.lua` reads them from config instead of holding them.
  Note the ceiling: provider *names* are hardcoded in ~18 places outside `providers.lua` (`chat.lua:171,187,249,368,1123`, `status.lua:52-60,144,171`, `chat_list.lua:102-118`, `pick.lua:63-70`). Config lets you retune the three shipped providers, not add a fourth. Say so in the README rather than pretending otherwise.
- `adapters` — the `ollama_adapter` factory and the `claude_code`/`opencode` ACP definitions currently in `plugins/codecompanion.lua:6-29,187-244`, including the 90s timeout, `session_config_options = { mode = "dontAsk" }`, the emptied `adapter.env`, the dropped `commands.yolo`, and the `clientCapabilities` hygiene. These carry the write defence, so they move as data the extension installs, not as something a colleague is asked to paste.
- `keymaps` (**`vim.g.ducktape`**) — every `<leader>c*` from `plugins/codecompanion.lua:36-161`, plus the buffer-local sets ducktape binds itself: `g2`/`g3`/`<leader>cj`/`<leader>ck` in `inline/init.lua:414-432`. `keymaps = false` suppresses **only the global defaults**; the `<Plug>` maps and the buffer-local diff maps are unaffected, and `keys.lhs`/`keys.label` still resolve against the default table so no message ever interpolates a `nil` key. Two consumers read this one field for different purposes — `plugin/ducktape.lua` asks "create the `<leader>c*` set?", `keys.lua` asks "what is this action's key called?" — so the table form must also allow `globals = false` alongside per-action overrides, otherwise "custom diff keys but no `<leader>c*` defaults" is inexpressible. Skipping conditions in step 6.
- `statusline = { enabled = true }` (**`vim.g.ducktape`**) — the segment injection currently in `config/options.lua:98-107`: relocated, and edited only where it names the module (append into `vim.o.statusline` left of the ruler, idempotent via the `find()` guard).
- `opencode = { relay = { cmd = "opencode-llm" }, models_json = { …3 paths… } }`.
- `set_default_adapters = true` — whether to claim codecompanion's chat/inline/cmd adapter defaults when they are untouched (see step 5, point 4).
- `codecompanion = {}` — passthrough, only consulted in the standalone-setup path below.

`health.lua` validates each route against **its own** allowed subset, not one shared list — `vim.g.ducktape` accepts only `keymaps` and `statusline`, extension `opts` accepts the rest. A right-name-wrong-table mistake (`vim.g.ducktape = { providers = … }`, which nothing ever reads) is the likeliest misconfiguration here and a shared list would wave it through.

### 4. `keys.lua` — one table, messages included

`keys.lhs(action)` and `keys.label(action)` resolve from config. The ~25 message sites that hardcode a key today are rewritten to interpolate: `inline/init.lua:228,551-553,1126,1161,1212,1273,1299,1383,1414-1417,1505,1599`, the chat footer tables (`chat.lua:39,43`) and the chat-list help table (`chat_list.lua:521-526`). The `g2 Accept | g3 Reject` banner (`inline/init.lua:1212`) derives from **ducktape's own** key table, not codecompanion's. It is tempting to source it from `interactions.shared.keymaps` since that is where the accept/reject *callbacks* come from, but ducktape passes `skip_default_keymaps = true` (`inline/init.lua:1214`) and binds `g2`/`g3` itself, hardcoded (`:414-419`) — cc's config happens to hold the same two letters, so the string is identical today and a colleague who remaps cc's `accept_change` would get a banner naming keys that are not bound. The one thing that *is* correctly cc-sourced is the `next_hunk`/`previous_hunk` **deletion** at `:397-403`, which must stay that way — it is deleting cc's mappings, so it has to read cc's values. With defaults unchanged every rendered string is byte-identical to today's; assert a few in the test suite.

### 5. Wiring: the extension, and `init.lua`

`lua/codecompanion/_extensions/ducktape/init.lua` is ~10 lines: `Extension.setup(opts)` → `require("ducktape").setup(opts)`, plus `Extension.exports` re-exporting the handful of functions the keymaps call so `codecompanion.extensions.ducktape.*` works.

`require("ducktape").setup(opts)` does, in order:

1. merge + validate config;
2. install adapters into the live cc config — `cfg.adapters.http.ollama/ollama_cloud`, `cfg.adapters.acp.claude_code/opencode`. Safe post-setup because ACP/HTTP adapters resolve **by name at use time** (`lua/codecompanion/adapters/acp/init.lua:114-117` reads `config.adapters.acp[name]`), which is also how our own `adapters.resolve(name)` calls reach them (`chat.lua:189,231,288`, `acp_pool.lua:208`). If a colleague already defined `claude_code`, deep-merge our defaults over theirs and warn rather than clobber;
3. override `cfg.interactions.chat.keymaps.send.callback` with `chat_edit.send` — the documented extension pattern, and equivalent to today's deep-merge since only the callback is replaced. Guard the assignment: `config.setup` strips disabled keymaps (`codecompanion/config.lua:1461`), so a colleague who disables `send` turns this into a nil-index, and because the extension runs inside cc's `pcall` that would abort every step after it;
4. set `cfg.interactions.chat.adapter = "claude_code"` and `inline.adapter`/`cmd.adapter = "ollama_cloud"` **only if the value is still `"copilot"`**, codecompanion's stock default (`codecompanion/config.lua:107` for chat, `:776` inline, `:811` cmd). By the time the extension runs, `config.setup(opts)` has already merged the colleague's own opts, so `"copilot"` is the only signal available for "untouched" — which means a colleague who *deliberately* chose copilot is indistinguishable from one who chose nothing. Give them `opts.set_default_adapters = false` to say so, and document that; do not pretend the check is smarter than it is;
5. `require("ducktape.debug").setup()`, `require("ducktape.reload").setup()`, and `require("ducktape.chat")` — the last for its load-time `setup_persistence()` (`chat.lua:1272`), which registers `VimLeavePre` and reads the pending-chats state. Order matters: it is what makes an nvim start cost zero agent subprocesses. These three already fire only at `VeryLazy` today (from `plugins/codecompanion.lua:247-249`), so the timing is unchanged.

Two things are deliberately **not** done here:

- **Keymaps** — `plugin/ducktape.lua` owns them, so they exist before codecompanion has loaded and pressing one is what pulls the core in.
- **The statusline segment** — also `plugin/ducktape.lua`. Today it is injected from `config/options.lua:98-107` at raw startup, live on the first redraw; doing it from this `setup()` would delay it to `VeryLazy` and leave a window with no segment. That window is the kind of "almost parity" that would go unnoticed for weeks. The injection itself is a string append and the render call inside it (`%{%v:lua.require'ducktape.statusline'.render()%}`) is an expression evaluated at redraw, so nothing is eagerly required by putting it in `plugin/`.

For anyone who would rather not route through cc's `extensions` block, `require("ducktape").setup(opts)` also works standalone and will call `codecompanion.setup(opts.codecompanion)` itself if codecompanion has not been set up yet. Documented as the secondary path; the extension is the recommended one.

#### The hazard this move introduces, and the contract that closes it

Today the keymaps live in **codecompanion's** `keys` table, and lazy's keys handler calls `Loader.load()` before it feeds the key through (`lazy/core/handler/keys.lua:121-133`). That makes one guarantee that the whole design leans on without ever saying so: **no ducktape action can run before `codecompanion.setup()` has, therefore never before the adapters and config are installed.** Moving the keys into `plugin/ducktape.lua` throws that guarantee away — the keys now exist from startup, whether or not the extension ever ran. Two things break, and both fail silently:

- **The write defence disarms.** `acp_pool.lua:208` and `chat.lua:189,231,288` resolve adapters *by name*. With ducktape's definitions not installed, those names resolve to codecompanion's **stock** adapters: opencode loses `env.OPENCODE_PERMISSION` — the `edit/write/patch/bash = "deny"` block from `providers.lua:413-422` and the only thing denying agent writes, since `install_write_guard` (`acp_pool.lua:95-103`) only refuses agent→client `fs/write_text_file` and not the agent's own tools — and claude regains `commands.yolo` and the 20s timeout. And the extension is loaded inside a `pcall` that only `log:error`s on failure (`codecompanion/init.lua:556-562`), so a colleague who typos `extensions.ducktape`, sets `enabled = false`, installs via `vim.pack` without wiring extensions, or trips any `vim.validate` rejection gets **fully working keymaps driving unhardened agents**.
- **Config arrives too late to be read.** `providers.lua:102` is `local state = vim.deepcopy(M.defaults)` — a chunk-time snapshot. Several actions reach `providers` with no codecompanion require in the path (`<leader>cmc` → `chat.lua:733` → `pick.lua:40`; `<leader>cs` → `status.lua:86`). Pressed before `VeryLazy`, the module snapshots the built-in defaults and a colleague's `defaults.chat.provider` is ignored for the rest of the session. Invisible on this machine, where `opts = {}`.

**The contract, and it must be written into the code, not just the README.** Every `plugin/ducktape.lua` callback begins with a `bootstrap()` that (a) `require("codecompanion")` — which, through lazy's `package.loaders` hook, loads codecompanion, runs its `config`, and therefore runs the extension, all synchronously before the require returns — and then (b) checks that ducktape's setup **ran to completion**, refusing the action with a loud message if not. Restoring the old invariant explicitly is the point; a comment saying "cc is always set up by now" would be the bug.

Make (b) a single flag set as the **last** statement of `ducktape.setup()`, and check that — not "are the adapters registered". The two differ in the case that matters: cc loads the extension inside a `pcall` (`codecompanion/init.lua:556-562`), so a throw part-way through setup leaves whatever ran before it in place and everything after it missing. Adapters go in at step 2 and the chat-persistence require is step 5, so an adapters-only check waves the action through in exactly the state where `VimLeavePre` never registered and open chats are not saved on exit.

Ordering inside `bootstrap()` matters: **codecompanion first, the ducktape module second.** The hazard is re-entrancy — `require` of a module whose chunk is still executing raises `loop or previous error loading module`, and inside cc's `pcall` that surfaces as a silently half-configured ducktape, not as an error the user sees. This codebase already hit it once and documents the fix: `debug.lua:12-16` defers its `acp_pool` require into a function precisely because "the pool's first statement is `require("codecompanion.acp")` — which, reached from a cold `require("ai.acp_pool")`, makes lazy.nvim load the plugin, run `config()`, and come straight back here into a module that is still loading."

The three modules that make this reachable are the ones with a chunk-level codecompanion require: `inline/init.lua:10`, `acp_pool.lua:8-11`, `inline/http.lua:4-5`. (`chat.lua` is *not* one of them — its only chunk-level require is `ai.ui` — so the chat actions are safe either way; the inline ones are not.) Concretely, the loop fires if `Extension.exports` holds eagerly-resolved references: `exports = { run = require("ducktape.inline").run }` evaluated at the extension's chunk level means a `<leader>ci` press starts loading `ducktape.inline`, hits its line-10 codecompanion require, cascades into cc setup → extension load → and that eager reference re-enters `require("ducktape.inline")` mid-chunk. So **`Extension.exports` entries must be closures** — `function(...) return require("ducktape.inline").run(...) end` — never resolved function references.

### 6. `plugin/ducktape.lua`, `health.lua`, `minimal.lua`

`plugin/ducktape.lua` — small, and with no eager `require` of the core (`lua-plugin-defer-require`):

- `vim.g.loaded_ducktape` guard, plus `vim.fn.has("nvim-0.11")` matching codecompanion's own floor (`plugin/codecompanion.lua` does exactly this);
- a `<Plug>(Ducktape…)` mapping per action, each body `bootstrap()` then `require("ducktape.…")` — see the bootstrap contract in step 5, which is what keeps a key pressed before `VeryLazy` from running against unhardened adapters — in the same modes the action has today — 13 are normal-only, and `<leader>ca`/`<leader>ci`/`<leader>cI`/`<leader>cn` are `{ "n", "x" }` (`plugins/codecompanion.lua:47,55,63,85`);
- the `<leader>c*` defaults pointing at those `<Plug>` maps, skipped entirely on `keymaps = false`, and skipped per-action on **two distinct checks that are easy to conflate**:
  - `vim.fn.hasmapto("<Plug>(DucktapeX)")` — `:h hasmapto()` is "whether a mapping exists whose **rhs** contains {what}", so this answers *"has the user already bound this action to a key of their own?"*, not *"is `<leader>ci` taken?"*. That is the doc's own `\ABCdoit` example. Its `{mode}` default of `nvo` does cover the four dual-mode actions, so no per-mode variant is needed.
  - `vim.fn.maparg(lhs, mode) ~= ""` — this is what answers *"is the key already taken?"*. Needed because `plugin/` scripts are sourced during `require("lazy").setup()`, which may run either side of a colleague's own `vim.keymap.set` in their `init.lua`; without it, whichever ran last wins and "their mapping wins" is a coin flip rather than a promise;
- the statusline injection (see step 5);
- the `:Ducktape` command with subcommand completion.

Reading config here needs care: `plugin/` scripts run before a lazy `config`/`opts` has been applied, so the keymap table can't come from `ducktape.setup()`. Resolve it from `vim.g.ducktape` — a plain table read at plugin-script time, exactly the pattern `lua-plugin-init` describes for Vimscript-compatible config — with **unset meaning "today's defaults"**, so a colleague who sets nothing gets the full `<leader>c*` set. Treat a `keymaps` key arriving later through extension `opts` as an override that re-creates the maps. Documented split: `vim.g.ducktape` for anything `plugin/` needs (`keymaps`, `statusline`), extension `opts` for everything else. **The one design detail worth a probe before committing** — confirm a `plugin/` script can read `vim.g.ducktape` set in the user's `init.lua`, i.e. that their `vim.g` assignment precedes `require("lazy").setup()`, which it does in this config (`init.lua` loads `config.options` before `config.lazy`) but need not in a colleague's.

`lua/ducktape/health.lua` returning `M.check()` (the interface `:checkhealth` looks for, per `health-dev`), modelled on `lua/codecompanion/health.lua`. It checks:

- codecompanion present and at/above the minimum version;
- **the internal APIs actually resolve** — not just the version number. `_G.codecompanion_buffers` is a table, `require("codecompanion.interactions.chat.parser").headers` and `.messages` are functions, `interactions.chat.acp.commands.link_buffer_to_session` and `.render.restore_session` exist, `config.interactions.shared.keymaps.next_hunk` is present. This is the guard the internal-surface list above exists for; a version floor alone would let a cc refactor through silently, and several of these are read with no `pcall`;
- `markdown` + `markdown_inline` parsers (the chat-edit transcript walk needs the markdown parser — `chat_edit.lua` `transcript()`);
- telescope (optional, names the two features lost without it); catppuccin (optional, names the fallback);
- `node`/`claude-agent-acp`, `opencode`, `opencode-llm`, `curl`, `jq`, `git`; `$OLLAMA_API_KEY` set; a reachable local ollama if `endpoint = "local"`;
- unknown keys in **both** config routes — the merged extension `opts` and `vim.g.ducktape` — and the resolved config echoed back.

`minimal.lua` at the repo root — the repro template `lua-plugin-troubleshooting` asks for, and what the fresh-colleague verification below runs.

### 7. Docs

`docs/how_to_use.md`, `docs/implementation.md`, `docs/keymaps.md` move over as the sources (945 lines, already accurate). `README.md` is new: what it is, the lazy spec, the prerequisites table, the config reference with defaults, the provider-names ceiling, and a "not vendored" note about `opencode-llm`. `Makefile` generates `doc/ducktape.txt` with panvimdoc so `:h ducktape` works, and runs stylua + tests. Dotfiles keeps `nvim/_nvim_ai/` as a stub pointing at the new repo, and `AGENTS.md`'s nvim rows get updated.

### 8. Prove it in a throwaway stowed config, with the real one untouched

The current nvim config is not modified to test this. Instead the `nvim` stow package is swapped for a minimal one that contains nothing but this plugin and what it needs, so the test measures the plugin rather than the rest of the config — and so a failure cannot take the daily driver with it.

```sh
cd ~/dotfiles
stow -D nvim              # drop the symlinks first; stow will not overwrite them
git mv nvim nvim_main     # park the real package
mkdir -p nvim/.config/nvim
# write the minimal config below, plus nvim/.stow-local-ignore excluding ^/install\.sh
stow nvim                 # ~/.config/nvim now points at the minimal package
```

Restore with the same three commands reversed (`stow -D nvim`, `git mv nvim_main nvim`, `stow nvim`). Two things to know while swapped: root `install.sh`'s `directories` array still says `nvim`, so running it during the test would stow the *test* package — don't; and `.stow_blacklist.local` is the clean way to park a package if the swap needs to outlive one sitting.

**Isolate the data directories, because stow does not cover them.** `~/.local/share/nvim`, `~/.local/state/nvim` and `~/.cache/nvim` are outside every stow package and would be shared with the real config. That matters concretely: lazy.nvim in the minimal config sees a different plugin set and will offer to clean the ones it does not recognise, which is the real config's entire plugin tree. So launch the test with its own XDG roots:

```sh
XDG_DATA_HOME=~/.local/share/dt-test \
XDG_STATE_HOME=~/.local/state/dt-test \
XDG_CACHE_HOME=~/.cache/dt-test nvim
```

That is not just a safety measure — it makes this the genuine first-run test as well: no `chat_sessions.json`, no `chat_titles.json`, no pre-installed parsers.

#### The complete dependency set — this is the answer to "is there anything else"

**Plugins the minimal config must declare:**

| Plugin | Why | Verdict |
|---|---|---|
| `folke/lazy.nvim` | bootstrapped as usual | required (or `vim.pack`) |
| `ducktape.nvim` (`dir = ~/projects/ducktape.nvim`, `lazy = false`) | the plugin | required |
| `olimorris/codecompanion.nvim` (`event = "VeryLazy"`, `opts.extensions.ducktape`) | the host | required |
| `nvim-lua/plenary.nvim` | codecompanion's own declared dependency (`codecompanion/health.lua` `M.deps`) | required |
| `nvim-treesitter/nvim-treesitter`, installing `markdown` + `markdown_inline` (either branch — `main`'s `require("nvim-treesitter").install{…}` or `master`'s `ensure_installed`) | **the one that is easy to miss.** Neovim 0.12.4 does not ship these parsers — on this machine they resolve to `~/.local/share/nvim/site/parser/*.so`, put there by nvim-treesitter. Chat rendering needs them, and so does `chat_edit.lua`'s `transcript()`, which parses the buffer with the `markdown` `chat` query. Under isolated XDG roots they are absent until installed, which is exactly the colleague's situation | required |
| `nvim-telescope/telescope.nvim` (+ plenary) | `<leader>cl` chat list and both `<leader>cm*` pickers. Without it those three report a clear error and everything else works | required to exercise all features; genuinely optional at runtime |
| `catppuccin/nvim` | the palette every `Ducktape*` highlight is derived from | optional — run once with it, once without, to confirm the teal fallback |

Not needed, checked: `blink.cmp`, `nvim-treesitter-textobjects`, `treesitter-modules.nvim`, `tree-sitter-rstml`, `markdown-preview.nvim`, `telescope-fzf-native`, conform, lspconfig, gitsigns. Nothing in `lua/ai/` references any of them.

**Options the minimal `init.lua` must set** — short list, but two of them are load-bearing:

- `vim.g.mapleader = " "` and `vim.g.maplocalleader = "\\"`, set **before** `require("lazy").setup()`. `<leader>` is resolved when a mapping is created, and `plugin/ducktape.lua` creates its maps during `lazy.setup()` — set it after and all 17 keys land on the wrong prefix.
- `vim.o.termguicolors = true`, or every `Ducktape*` highlight is silently ignored.
- Nothing else. The layer reads only `columns`, `lines` and `cmdheight` (`ui.lua:24,111-114`, `pick.lua:372-381`, `debug.lua:29-34`) and touches no other global option.

**Outside nvim** — the same list as the dependency table earlier, and all of it must be present in the *shell that launches nvim*, not just installed:

- `node` + `claude-agent-acp` for claude, `opencode` for opencode, `opencode-llm` + `jq` for the tool-free relay, `curl` for ollama, `git` for the chat list's repo scoping, a running `ollama` only if you switch the endpoint to local.
- `$OLLAMA_API_KEY` exported, and `$CLAUDE_CODE_OAUTH_TOKEN` inherited from the environment.
- **The nvm trap.** `config/options.lua:15-43` appends the newest nvm node bin dir to `vim.env.PATH` precisely because nvm exposes `node` as a shell function, so a GUI-launched or bare-shell nvim has no `node` and `claude-agent-acp` fails with ENOENT. The minimal config has none of that, so either launch it from a shell where `node` resolves, or carry the shim across. Either way this belongs in the README — a colleague using nvm hits it on day one, and the symptom is an ACP session that never answers rather than an error naming node.

#### What to check while swapped

Everything in the Verification section below, run against this config rather than the real one. It doubles as the fresh-colleague simulation: if a feature needs something the table above does not list, it fails here, which is the point of testing in a config that contains nothing else.

### 9. Switch the dotfiles over

**Deferred — not part of this work.** The real nvim config is not touched at all; step 8's
throwaway package is how the plugin gets exercised, and it is reversed afterwards. Whether to point
the daily driver at the plugin is a separate decision, taken later. What follows is the recipe for
that day.

`nvim/.config/nvim/lua/plugins/codecompanion.lua` becomes two entries:

```lua
{ dir = vim.fn.expand("~/projects/ducktape.nvim"), lazy = false },   -- plugin/ must run at startup
{
  "olimorris/codecompanion.nvim",
  event = "VeryLazy",                                            -- KEEP THIS
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = { extensions = { ducktape = { opts = {} } } },
}
```

`opts = {}` is the point: the defaults *are* this machine's config. The 17-entry `keys` table goes away — the plugin owns its own lazy-loading now.

**Do not drop `event = "VeryLazy"` from codecompanion.** lazy.nvim derives laziness from the spec: `plugin.lazy = plugin._.dep or Config.options.defaults.lazy or plugin.event or plugin.keys or plugin.ft or plugin.cmd` (`lazy/core/plugin.lua:235-242`), and `config/lazy.lua` never sets `defaults.lazy`. With `keys` removed and `event` gone too, codecompanion computes to `lazy = false` and lazy.nvim loads it *synchronously during startup* — dependencies, `config`, `setup()`, extension and all. That is strictly worse than today, where `VeryLazy` defers it to an autocmd after the UI is up. `ducktape` is the one that wants `lazy = false`; codecompanion is the one that must stay deferred.

Also remove the statusline block from `config/options.lua:98-107` (now `plugin/ducktape.lua`), and keep the nvm PATH fix (an editor concern; the README mentions the failure mode for colleagues whose node comes from nvm). Then `git rm -r lua/ai/`, and `mv ~/.local/state/nvim/ai ~/.local/state/nvim/ducktape` once so open chats and titles carry over.

Do this as the **last** step, after parity is verified from the `dir=` spec on a branch — the daily driver stays working the whole way through.

## Verification

0. **The move was a move.** `git diff --stat` on the copied tree, read against the rename table, should show nothing but renames and the three sanctioned edit kinds from the ground rule. Anything else in that diff is scope that crept in and should come back out before going further.
1. `make test` — all 9 suites, expecting **517 assertions, 0 failures**, same as today. Plus new assertions that the rendered message strings match the current hardcoded text under default keymaps.
2. `stylua --check lua/ tests/`; `lua-language-server` clean (CI does this on nvim 0.11 / 0.12 / nightly).
3. `:checkhealth ducktape` on this machine — everything green except whatever is genuinely absent.
4. **Parity pass** on the real thing, against `docs/keymaps.md`: `<leader>cc` toggle and restore-after-restart; `<leader>cn` new chat; `<leader>cl` list, rename, `<C-d>`, `<C-x>`; `<leader>cd` delete; `<leader>ci` on a selection with ollama, then claude, then opencode; `<leader>cI` with claude; `g2`/`g3`/`<leader>cj`/`<leader>ck` on a pending diff (and that `{`/`}` still do their plain paragraph motion in the code buffer rather than jumping codecompanion's hunks — that is what the `inline/init.lua:397-403` deletion restores); `<leader>cL` list and `<leader>cA`/`<leader>cR`; `<leader>cx`/`<leader>cX`; `<leader>cs` status panel including a live option change; `<leader>cmi`/`<leader>cmc` pickers with their confirm step; the chat-edit fork — edit a past answer, ask again, confirm the new session answers from the edited text and the title carried over. Also the visual-mode halves of `<leader>ca`/`<leader>ci`/`<leader>cI`/`<leader>cn`, which the `<Plug>` rewrite could silently drop. And the three paths that carry the old branding into places a grep of `[ai]` alone would miss: take an inline prose reply into a chat from `<leader>cL` (both `<CR>` on a prose/failed row and `a` on a prose row — `inline/init.lua:1774,1796`), and run `:Ducktape send` with no arguments to see its usage line.
5. **Everything below runs in the swapped-in minimal config from step 8**, not the real one. Two extra runs there, to prove the optional deps really are optional: drop telescope and confirm the chat list and both pickers report the existing clear error while the rest works; drop catppuccin and confirm the teal fallback. `:checkhealth ducktape` must name exactly what is missing in each case. Then confirm `{ "you/ducktape.nvim" }` on its own pulls plenary, treesitter and telescope via `lazy.lua`, and that codecompanion is *not* dragged in eagerly by it.
6. **Load timing, measured rather than assumed.** Right after startup, with no ducktape key pressed: `:lua print(package.loaded["codecompanion"] ~= nil, package.loaded["ducktape.chat"] ~= nil)` must print `false false`, and `:Lazy` must show codecompanion as not-loaded — that is what proves the deferral, whereas an empty `:Ducktape pool` proves nothing (the pool only fills on a real agent connection, so it is empty either way). Then confirm `<leader>cc` alone loads both and opens a chat. Confirm the statusline segment is present on the *first* redraw, before `VeryLazy` — start with `nvim --headless -c 'redraw' -c 'lua print(vim.o.statusline)'`. Finally compare `--startuptime` against today's `keys`-based spec.
7. **The keymap hedge, which nothing else exercises.** In the minimal config: map `<leader>ci` to something of your own before ducktape loads and confirm ducktape leaves it alone while its other 16 defaults still appear (the `maparg` path — note `hasmapto` alone would *not* catch this, which is what makes the check worth testing); separately, map your own `<leader>zi` to `<Plug>(DucktapeInline)` and confirm ducktape then skips its own `<leader>ci` default (the `hasmapto` path); then **relaunch** with `vim.g.ducktape = { keymaps = false }` set in the config — not toggled live, since `plugin/ducktape.lua` reads it once at startup and never re-runs — and confirm no `<leader>c*` default exists while every `<Plug>(Ducktape…)` still does, and that a hand-rolled `vim.keymap.set("n", "<leader>zz", "<Plug>(DucktapeChatToggle)")` works. Then, still under `keymaps = false`, drive an inline request to a pending diff and confirm `g2`/`g3`/`<leader>cj`/`<leader>ck` are still bound in the buffer and the banner renders real keys — `false` must not reach the buffer-local set or leave `keys.label()` returning `nil`. Finally confirm the messages that name keys read correctly under a remap, which is what step 4's `keys.label()` is for.
8. **The write defence, adversarially.** This is the one regression that could ship silently, so test the disarmed path on purpose. (a) Press `<leader>ci` as the very first action after startup, before `VeryLazy` can have fired — confirm the request runs and that `:Ducktape pool` then shows a connection built from *ducktape's* adapter (opencode's `OPENCODE_PERMISSION` present, claude's timeout 90s, no `yolo` command). (b) Delete the `extensions.ducktape` entry from the spec entirely and confirm every key refuses with a loud message rather than proceeding against stock adapters. (c) Make `ducktape.setup` throw part-way through — a malformed `providers` or `adapters` table passed through `opts.extensions.ducktape.opts`, *not* a bad `vim.g.ducktape`, which by design never reaches `setup()` at all — and confirm the same refusal even though the adapters from step 2 did get installed before the throw. That is the case an adapters-only check would wave through. (d) In case (a) only, confirm open chats still save on exit; in (b) and (c) nothing can be opened to save, which is the correct outcome rather than a passing check.
9. **Both managers**: `:Lazy update` against the pushed GitHub repo from a second checkout with `version = "*"` resolving to the first release-please tag; and a `vim.pack.add({ { src = …, version = vim.version.range('1.0') } })` config resolving the same tag, then `vim.pack.update()`.

## Out of scope

Adding a fourth provider kind; refactoring the provider-name hardcoding; porting the tests to busted or mini.test; luarocks publishing; vendoring `opencode-llm`; the in-process-LSP code-action UI the Neovim docs suggest; and the two known-but-unasked items (`chat_list.lua`'s `relative_time` timezone bug, the footer-colour check against a real `StatusLine` background) — they travel with the code exactly as they are.

See the ground rule at the top: the existing implementation is the specification. Nothing here is an invitation to improve it while moving it.
