# Step 06 — Chat list

**Goal** One picker for both live nvim chats and past agent sessions, including sessions started outside nvim.

**Files** `nvim/.config/nvim/lua/ai/chat_list.lua`

**Depends on** 01 (pool, for the connection that lists sessions) and 04 (chat creation, for restore).

**Evidence** `findings.md` → *Session listing works and is cross-tool*.

## Design

Telescope picker — telescope and `telescope-fzf-native` are installed and loaded eagerly. Prompt at the bottom, `sorting_strategy = "descending"` so best matches sit next to the prompt.

Two groups:

1. **live** — open nvim chats from `interactions.shared.registry`, marked and sorted first
2. **resumable** — past claude/opencode sessions from `session/list`, showing `title` and relative `updatedAt`

Filter resumable sessions by **git root**, matching each session's `cwd` as a prefix. Not `getcwd()`: `_establish_session` hardcodes the cwd at creation time, so a `getcwd()` filter makes sessions vanish whenever nvim is opened in a subdirectory or the user `:cd`s.

Selecting a live chat focuses it. Selecting a past session opens a fresh chat and restores it via `acp_connection:load_session(id)` + `interactions.chat.acp.render.restore_session` — the mechanics `/resume` uses — which must happen **before** the first message.

Picker actions: open (`<CR>`), close one (`<C-d>`), close all, new chat. History is fetched once per nvim session and cached. Listing reuses a live connection when one exists; otherwise it pays the lazy spawn.

## Done when

- a session started by a terminal `claude` in this repo appears in the list and restores with its history
- the same holds when nvim was opened from a subdirectory of the repo — the git-root filter is the point
- a session from an unrelated repo does **not** appear
- live chats sort above resumable ones and focusing one does not create a second buffer
- `<C-d>` closes a single chat without disturbing the others
- listing with no live connection pays one spawn and then caches
