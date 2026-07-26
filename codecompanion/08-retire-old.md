# Step 08 — Retire the old configuration

**Goal** Remove what the rebuild replaced, leaving `lua/plugins/codecompanion.lua` as a lazy spec and nothing more.

**Files**

- `nvim/.config/nvim/lua/plugins/codecompanion.lua`
- `nvim/.config/nvim/lua/config/keymaps.lua`

**Depends on** 03–06. Do not start until the replacements work, or there is no rollback.

## What goes

The old inline machinery in `codecompanion.lua` — the ollama `format` JSON schema, `FULL_SELECTION_HINT`, the busy flag and its reset, the ad-hoc per-provider model pickers, the thinking toggle. All of it is superseded: placement is now nvim's, the prompt carries the context the JSON schema was faking, and options come from the shared schema.

What stays in that file: the lazy spec — dependencies, keymaps, `setup()`, and the adapter definitions from step 01.

`lazy.nvim` imports `lua/plugins/*.lua` non-recursively, which is why every implementation module lives under `lua/ai/` instead.

## Keymap comment block

`lua/config/keymaps.lua:150-158` documents the current `<leader>c*` bindings and will be stale in three specific ways. Update it against `00-overview.md` → *Key bindings*:

- `<leader>ct` is gone — `think` is a status-panel row now
- `<leader>cx` changes meaning — it cancelled nothing before, it reset a stuck busy flag; now it cancels in-flight requests
- `g1` is gone — the comment currently advertises it as "always accept"
- `<leader>cI`, `<leader>cj`, `<leader>ck` and `<leader>cl` are new and undocumented there

## Done when

- `codecompanion.lua` contains no inline logic — the module is a spec plus adapters, and `rg 'FULL_SELECTION_HINT|format\s*=' ` on it comes back empty
- no keymap in the comment block is absent from the implementation, and none in the implementation is absent from the comment block
- pressing each binding in the table does what the table says, checked by hand once
- nvim starts with no error and nothing ACP spawns until first use
- the old thinking toggle and busy-flag reset are gone and nothing references them
