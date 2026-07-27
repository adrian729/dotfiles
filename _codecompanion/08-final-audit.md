# Step 08 — Final audit and documentation

**Goal** Confirm the rebuilt integration matches what this directory describes, and restore the keymap documentation that step 00 gutted.

**Files** `nvim/.config/nvim/lua/config/keymaps.lua`

**Depends on** 03–06. Nothing to audit until every binding exists.

There is no code to retire here. Step 00 deleted the old integration outright and every step since built on a clean slate, which is exactly why this step is small. If you find yourself removing dead code now, something survived step 00 — that is a finding, not a chore.

## Keymap comment block

Step 00 replaced `lua/config/keymaps.lua:150-158` with a marker pointing at this directory. Restore it now, in one pass, against `README.md` → *Key bindings*, which is authoritative. Doing it incrementally would have meant rewriting the block six times and getting it wrong at least once.

The restored block differs from the pre-rebuild one in five ways, all deliberate:

- `<leader>ct` is gone — `think` is a status-panel row
- `<leader>cx` means cancel now, not "reset a stuck busy flag"
- `g1` is gone — `skip_default_keymaps` stops the plugin binding it, and blanket per-buffer approval is meaningless with several diffs pending
- `<leader>cI`, `<leader>cj`, `<leader>ck` and `<leader>cl` are new
- `<leader>ci` no longer reads "ollama, JSON-forced" — the provider is a runtime choice and the JSON schema is gone

Omit the Step column when transcribing; it matters to someone building this, not to someone reading `keymaps.lua`.

## Audit

The real job is catching drift between what this directory says and what got built. Check in both directions, since only one direction catches accidental extras:

- every row of README's *Key bindings* is bound, **and** `:map <leader>c` contains nothing absent from that table
- every module in README's *Module layout* exists, **and** `lua/ai/` contains nothing absent from that list
- `lua/plugins/codecompanion.lua` is still only a lazy spec plus adapters and keymaps — no logic crept back in
- each earlier step's own done-when list still passes, not merely when it was first written

## Done when

- the comment block matches README's *Key bindings* row for row
- pressing every binding does what the table says, checked by hand once
- nvim starts clean and nothing ACP spawns until first use — `:AiPoolStatus` empty at startup
- `rg 'FULL_SELECTION_HINT|spinner|ollama_adapter|vim\.g\.ollama' nvim/` is empty across the whole config, not just the plugin file
- any divergence found during the audit is either fixed or written into README's *Open items* — not left in your head
