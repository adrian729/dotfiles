# Step 00 — Strip to a bare plugin

**Goal** Delete the existing integration entirely, leaving `codecompanion.nvim` installed and configured with nothing of ours. Every later step then builds from zero rather than negotiating with what was there.

**Files**

- `nvim/.config/nvim/lua/plugins/codecompanion.lua` — 373 lines down to roughly 15
- `nvim/.config/nvim/lua/config/keymaps.lua` — the `<leader>c*` comment block at 150-158

**Depends on** nothing. **Do this first.**

## Why demolish instead of migrate

The alternative — keeping the old config alive and flipping one feature at a time — means every step from 01 to 08 has to reason about two implementations binding the same keys, and about which half of the behaviour is live. That is a lot of accidental complexity to carry for the sake of a fallback that git already provides.

The cost is a **blackout**: between this step and step 01 there is no working AI integration in nvim at all, and no chat until step 01 restores the adapters. Step 01 is small and self-contained, so keep the window short. If that is unacceptable on a given day, do 00 and 01 in one sitting.

## What goes

Everything in `codecompanion.lua` except the lazy spec itself. This table is the **ledger**: every row must name a restoring step, or say explicitly that the thing is not coming back. A row with no owner is a silent regression, which is the failure mode this whole step invites.

| Removed | Restored by |
|---|---|
| `inline_run`, `inline_reset`, `FULL_SELECTION_HINT` | step 03 |
| the `Inline` busy flag, `SPIN`, `spinner_start`/`_stop`/`_render` | step 03's per-request virtual text; the helper lands in `ui.lua` |
| the **inline** spinner autocmds and the `CodeCompanionInlineSpinner` augroup | step 03 |
| the **chat** "thinking…" autocmds on `CodeCompanionChatSubmitted`/`Done` | step 04 — easy to miss, since it is the same augroup as the inline pair |
| the `ollama_inline` JSON-schema `format` body | nothing — its job is done by the prompt, per the contract |
| `ollama_adapter`'s `num_ctx = 16384` and `keep_alive = "30m"` | step 01, explicitly. Losing `num_ctx` truncates long refactors with no error |
| `ollama_adapter`'s `env.url`, `model` and `think` schema functions | step 01's adapters, reading `providers.lua` instead of `vim.g` |
| `pick_ollama_model`, `toggle_ollama_think`, `vim.g.ollama_inline_model`, `vim.g.ollama_think` | steps 01 and 05; the globals do not return |
| `new_chat`, `close_all_chats`, `chat_model`, `show_status` | steps 04 and 05 |
| the whole `keys` table — all nine bindings | steps 01, 03, 04, 05, 06, per README's *Key bindings* Step column |
| the `adapters` block | step 01 |
| the `strategies` block, including `chat.adapter = "claude_code"` | step 01 — without the default, `:CodeCompanionChat` picks an adapter this machine has no credentials for |
| `opts = { log_level = "DEBUG" }` | nothing — it was a temporary aid for debugging the ACP handshake, which is done |

Two things deliberately do not come back: `<leader>ct`, since `think` becomes a status-panel row like every other provider option, and the JSON `format` schema, since nvim now owns placement.

Nothing outside this file depends on any of it — checked: no other file in the nvim config reads `vim.g.ollama_inline_model` or `vim.g.ollama_think`, and the only external mentions of codecompanion are two comments.

## What stays

```lua
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
    config = function()
      require("codecompanion").setup({})
    end,
  },
}
```

Keeping `cmd` preserves lazy-loading and leaves `:CodeCompanionChat` reachable by command. Note it will **not work** until step 01 supplies an adapter — with no `adapters` block the plugin falls back to its own default, which this machine has no credentials for. That is expected and is the blackout described above.

## Keymap comment block

Replace `lua/config/keymaps.lua:150-158` with a two-line marker pointing at this directory. Restoring it properly is step 08's job, once the full binding set exists and can be documented accurately in one pass. Leaving the old block in place through the rebuild would mean nine lines of documentation that describe nothing.

## Done when

- `codecompanion.lua` is the spec above and nothing else — `rg 'FULL_SELECTION_HINT|spinner|ollama_adapter|inline_run|show_status|vim\.g\.ollama' ` on it comes back empty
- no `<leader>c*` keymap is bound anywhere — `:map <leader>c` lists nothing
- nvim starts with no error and no warning
- `:CodeCompanionChat` opens and fails on the missing adapter rather than erroring at load — a working plugin with no configuration, not a broken one
- the keymaps.lua comment block no longer describes bindings that do not exist
- `git diff --stat` shows one file shrinking by ~350 lines and nothing else touched outside these two files
- every row of the ledger above names a restoring step or an explicit "does not come back" — re-read it against the deleted code once, since anything missed here resurfaces as a regression nobody is looking for
