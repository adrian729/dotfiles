# Step 05 — Status panel

**Goal** One interactive surface for every provider option, generated from the schema so it never needs per-provider code.

**Files** `nvim/.config/nvim/lua/ai/status.lua`

**Depends on** 01 (schema, reach) and 04 (a live chat to apply changes to).

**Evidence** `findings.md` → *Transport reach*, *Session config options are settable declaratively*, *Provider capability matrix*.

## Layout

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

## Behaviour

- `j`/`k` or arrows move between rows
- `<CR>` enters edit mode on a row; `h`/`l` cycle values in place; `<CR>` commits, `<Esc>` reverts
- rows are generated from the provider schema, so a provider gaining an option needs no changes here
- the inline provider row carries a **reach** marker — tool-free (ollama either endpoint, opencode relay) or can-read-the-machine (either ACP transport) — because that property follows the selected provider and transport rather than the keymap, and is otherwise invisible at the moment you press `<leader>ci`. Read it from `providers.lua`, not from a copy of the table in `findings.md`.
- committing applies live to the focused chat's session via `set_config_option`, and updates the stored default for future chats and inline requests
- changing the provider row re-renders the rows below it for that provider's schema
- changing the inline model drains the connection pool rather than mutating a live session

## Done when

- changing effort on a live claude chat is confirmed in the `gd` debug window as `thought_level` on the session — not merely reflected in the panel
- changing the inline provider re-renders the rows below and updates the reach marker
- switching the inline model drains the pool: the old connection is gone and the next request spawns fresh
- `<Esc>` mid-edit leaves both the panel and the session unchanged
- a provider option added to the schema appears in the panel with no edit to this file
