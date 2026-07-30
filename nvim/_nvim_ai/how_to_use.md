# How to use the AI integration

## Inline editing

Inline editing modifies code directly in your buffer. You pick *what* to change and *where*; the model supplies the replacement code. No tools, no autonomous multi-step work, no side effects. The model never decides where its output lands.

**Making an edit:**
1. Optionally, make a visual selection of the code you want to change
2. Press `<leader>ci` (no tools, no repo reads) or `<leader>cI` (may read the repo to learn conventions; works on claude and opencode only)
3. Type your instruction in the floating prompt and press `<CR>`

`<leader>cI` only works with ACP providers (claude, opencode). On ollama it shows a message telling you to switch providers — ollama has no tool access outside of HTTP, so it cannot read the repo.

With a visual selection, the reply replaces exactly that range. Without a selection, the reply is inserted at your cursor. Up to 40 lines above and below the selection are included in the prompt as context. LSP diagnostics in the range are included automatically. The floating prompt and the progress spinner both show the provider and model.

You can have several inline requests in flight in the same buffer at once. Each one gets a spinner on its target row and an independent diff when it lands.

**Reviewing and applying edits:**

When a reply arrives it is rendered as a diff — the original code shown as deletions, the new code as additions. Until you act on it, the buffer is **not** permanently changed.

- `g2` — accept the diff under your cursor (makes the change permanent)
- `g3` — reject the diff under your cursor (restores the original)
- `<leader>cj` / `<leader>ck` — move to the next/previous hunk in the diff under your cursor

When your cursor is outside any diff but only one diff is pending, `g2`/`g3` act on that one.

If you close the buffer or the last window showing it while a diff is pending, the diff is rejected automatically — your buffer is not left in a half-applied state.

**Cancelling in-flight requests:**

Press `<leader>cx`. If your cursor is on the line where an inline request is in flight, that request is cancelled. In a chat buffer, it stops the running agent.

Press `<leader>cX` to cancel every in-flight inline request in the buffer at once.

**Switching provider or model:**

Press `<leader>cmi`. You are prompted to pick a provider, then a model (two pickers, in order):

- **ollama** — sub-pick `cloud` (free, fast, always available) or `local` (private, needs ollama running). Model lists are fetched live from the ollama API and cached for the session
- **claude** — runs over ACP. You can also pick the effort level (default/medium is what inline uses; higher effort is slower and more expensive). Fast mode (on claude models that offer it) trades some quality for speed. The session runs in `dontAsk` mode, which denies mutating tools
- **opencode** — for `ci` runs through the `opencode-llm` relay (a free-tier cloud model, no tools at all). For `cI` runs over ACP with repo-read permission but mutation denied

Defaults: ollama cloud with `gpt-oss:120b` — measured ~4s on a typical refactor, no local RAM cost, free.

**When the model declines:**

If the model returns an explanation or says it cannot do the edit, a float opens with the response. Press `<CR>` in that float to open a chat buffer pre-loaded with the exchange — your instruction, the selection, and the model's reply — so you can continue the conversation there.

---

## Chat

Chat is a full conversation buffer where you can talk to a model, invoke tools, run slash commands, and share editor context. It works with all three providers.

**Starting and managing chats:**

- `<leader>cn` — start a new chat with the current provider and its preset options. The buffer title shows `provider · model` until the chat auto-titles from your first message
- `<leader>cc` — toggle the last chat buffer (creates a new one if none exists)
- `<leader>cq` — close all chat buffers
- `<leader>cr` — rename the current chat
- `<leader>cd` — delete the current chat *and* the agent's saved transcript of it (asks first; cannot be undone)
- `<leader>cl` — open the chat list (Telescope picker, see below)

**Switching chat provider or model:**

Press `<leader>cmc`. Same picker flow as inline but for the chat scope. Defaults: claude with opus + xhigh effort + acceptEdits mode.

**Chat list:**

`<leader>cl` opens a Telescope picker showing three sections:
- **Live chats** — every open chat buffer, suffixed with its `provider · model`. `<CR>` focuses it
- **From last session** — chats that were open when nvim last quit and haven't been reopened yet, marked `(from last session)`. `<CR>` starts one and replays its history. Nothing is running behind these
- **Resumable sessions** — every other past ACP session (including ones started in a terminal outside nvim), filtered to the current git repo. `<CR>` opens it in a new chat buffer with full history

Each line leads with two markers, also spelled out in the picker's results border:

| Marker | Means |
|---|---|
| `▶` | The chat `<leader>cc` reaches. Always listed first |
| `●` | Agent up and ready to take a message |
| `◌` | Agent still starting. Sending now would fail |
| `✕` | Agent process is gone. The buffer survived a crash; reopen the session to get a working one |
| `○` | Not started — no agent behind it at all until you open it |

Anything not `●` also carries a short reason in dim text, since a coloured glyph alone doesn't say what's wrong. Ready-but-hidden chats are annotated `(hidden)` — they hold a running agent even though no window shows them.

Every section takes the same three edits, listed in the picker's own results border:

| Key | Does |
|---|---|
| `<C-r>` (or `r` in normal mode) | Rename. Live chat, pending chat, or stored session alike |
| `<C-d>` | Stop it coming back, without deleting anything. On a live chat that closes the buffer and frees its agent; on a pending one it drops out of the reopen set and becomes an ordinary stored session |
| `<C-x>` | Delete for good — the chat *and* the agent's copy of the conversation. Asks first |

Renaming is local: agents name a session from their own summary of it and ACP has no way to override that, so chosen names are kept in `~/.local/state/nvim/ai/chat_titles.json`, keyed by session ID. That is also what makes a rename stick — the agent pushes a fresh auto-title at the end of every turn, and a name you chose is re-applied over it.

Sessions are cached; the list updates on each open.

**Chats survive restarts:**

Open ACP chats are remembered per directory. On quit, their session IDs are written to `~/.local/state/nvim/ai/chat_sessions.json`; the next time you start nvim in the same directory they wait in `<leader>cl` under **from last session**, and open on demand.

Nothing is started for you. A restore spawns an agent subprocess and makes a blocking `session/load` round trip, so starting them eagerly meant paying for chats you might never look at — an nvim start now costs zero agent processes no matter how many chats were open when it quit. `<leader>cc` reopens the most recent one when no chat is live, so continuing where you left off is still one keypress; `<leader>cn` is what asks for a fresh chat instead.

The agent keeps its own memory across the restart — this resumes the real ACP session (`session/load`), it does not just repaint the text. A follow-up question can refer back to anything from before the restart.

Notes:
- Reopening takes a few seconds while the agent starts and replays the transcript. Only the chat you picked pays that cost.
- Pending chats are read straight from the JSON, so they show instantly and are listed even with no agent running anywhere.
- Only ACP chats (claude, opencode) persist. ollama chats are HTTP with no server-side session, so they cannot be resumed.
- Closing a chat (`<leader>cq`, or `<C-d>` in the chat list) drops it from the saved set, so it is not reopened on the next start — but its session survives and stays resumable from `<leader>cl`. `<leader>cd` / `<C-x>` is what removes the session itself.
- A name you gave a chat comes back with it, and keeps applying to the session afterwards even if you close the chat.
- There is no cap. Nothing is spawned until you pick something, so however many chats were open, all of them wait in the list.
- A pending chat you never open stays pending across as many restarts as you like — quitting does not quietly drop it.
- A chat you opened but never sent a message in comes back as an empty chat. The agent only commits a session to its own store once there has been a real exchange, so there is no history to reload — but the chat itself reopens on its original provider/model rather than disappearing.
- If a saved session has since been deleted or aged out of the agent's store, the chat still reopens, just without its transcript, and you get one `[ai] session <id> is gone — reopened without history` warning.

**Agent edits show up in your open buffers:**

The chat agent edits files on disk rather than through nvim, and nvim does not notice that by itself — so a file you had open used to keep showing the pre-edit text while the version underneath it had moved on. Save from that stale buffer and you overwrite the agent's work.

Buffers now follow those edits automatically. The agent reports each file it touches, and the matching buffer is reloaded, with the cursor and scroll position kept where they were. A sweep at the end of every turn catches anything edited without being reported — a shell redirect, or a script the agent ran.

The one case left to you is a genuine conflict: if the buffer has **unsaved changes** and the agent also changed the file, neither version is touched, and you get

```
[ai] foo.lua was edited by the agent but has unsaved changes here — :e! to take the agent's version, :w to keep yours
```

Picking a winner automatically would throw away one side silently, so it asks instead. Note that this only applies to *chat*, which runs in `acceptEdits` mode; inline (`<leader>ci` / `<leader>cI`) works on your buffer directly and denies file writes outright.

**Inside the chat buffer:**

The chat buffer has its own set of keymaps and features. Send a message with `<CR>` or `<C-s>` in normal mode (or `<C-c>` in insert mode). Stop a running request with `q`.

| Feature | How |
|---|---|
| Change adapter/model | `ga` opens the adapter selector |
| Debug window | `gd` shows full message history, adapter config, and context items. Editable — `<C-s>` persists changes back to the chat |
| Regenerate | `gr` re-sends the last prompt |
| System prompt | `gs` toggles it on/off |
| Clear chat | `gx` clears the buffer content |
| Fold codeblocks | `gf` folds/unfolds code blocks |
| Insert codeblock | `gc` |
| Yank last codeblock | `gy` |
| Go to file under cursor | `gR` |
| Clear all rules | `gM` |
| Between-turn message | `gm` sends a message while the LLM is still streaming |
| Sync full buffer every turn | `gba` |
| Sync buffer diff every turn | `gbd` |
| Navigate chats | `{` / `}` for previous/next chat |
| Navigate headers | `[[` / `]]` for previous/next message header |
| Show keymaps | `?` opens the chat buffer's action palette |
| Reset tool approvals | `gtx` resets all `always allow` decisions for this chat |
| YOLO mode | `gty` auto-approves tool calls (dangerous — excludes delete/run_command by default) |
| Copilot usage stats | `gS` shows usage statistics |

Some adapters expose a `show_settings` yaml block at the top of the chat buffer where you can tweak model parameters between responses. Enabled by `display.chat.show_settings = true`.

Chat buffers also support automatic title generation (needs background interactions enabled in config).

**Sending context to the LLM:**

All chat features below work by typing the trigger character followed by the name. Completion is available via nvim-cmp or blink.cmp (or native `<C-_>`). Context items appear in a `Context` blockquote in the chat buffer.

**Editor Context** — type `#` in the chat buffer:

| Context | What it shares |
|---|---|
| `#{buffer}` | Current buffer (diff by default; `{all}` for full content) |
| `#{buffers}` | All open buffers |
| `#{code_review}` | Pending code review comments |
| `#{diagnostics}` | LSP diagnostics for current buffer |
| `#{diff}` | Current git diff (staged + unstaged) |
| `#{messages}` | Neovim's `:messages` history |
| `#{quickfix}` | Quickfix list contents |
| `#{selection}` | Last visual selection |
| `#{terminal}` | Last terminal buffer output |
| `#{viewport}` | What you see on screen |

Buffer context can be synced so the LLM receives updates on each turn. Use `#{buffer}{all}` to send the full buffer every turn, or `#{buffer}{diff}` (the default) to send only changes.

**Slash Commands** — type `/` in the chat buffer:

| Command | What it does |
|---|---|
| `/acp_session_options` | Change ACP session config options (adapter models, modes, etc.) |
| `/buffer` | Add contents of one or more open buffers |
| `/command` | Switch ACP adapter command (ACP adapters only) |
| `/compact` | Summarize chat history and clear old messages, preserving system prompt and rules |
| `/fetch` | Fetch and add content from a URL |
| `/file` | Add contents of one or more files (including PDFs for supported adapters) |
| `/fork` | Duplicate the chat buffer with full history (HTTP adapters only) |
| `/help` | Add vim help content |
| `/image` | Add an image from a file or URL (vision-capable models only) |
| `/mcp` | Start or stop MCP servers |
| `/mode` | Switch ACP agent operating mode (ACP adapters only) |
| `/now` | Insert current datetime stamp |
| `/resume` | Resume a previous ACP session into this chat (fresh buffer only) |
| `/rules` | Add rules groups to the chat |
| `/share` | Share the conversation as a secret GitHub Gist |
| `/symbols` | Add a Tree-sitter symbol outline of a file |

**Tools and Agents** — type `@` in the chat buffer:

Tool groups combine multiple tools. `@{agent}` enables autonomous coding (creates files, runs commands, searches code). `@{files}` enables file operations only. Individual tools can also be invoked:

| Tool | What it does |
|---|---|
| `@{agent}` | Autonomous coding agent: reads, writes, searches, runs commands |
| `@{files}` | File operations: create, delete, read, insert-edit, search |
| `@{ask_questions}` | Ask clarifying questions before acting |
| `@{create_file}` | Create a file in the working directory |
| `@{delete_file}` | Delete a file in the working directory |
| `@{fetch_webpage}` | Fetch and parse webpage content |
| `@{file_search}` | Search for files by glob pattern |
| `@{get_changed_files}` | Get git diff of changed files |
| `@{get_diagnostics}` | Retrieve LSP diagnostics for a file |
| `@{grep_search}` | Search file contents with ripgrep |
| `@{insert_edit_into_file}` | Apply code edits to files or buffers |
| `@{memory}` | Store and retrieve information across chats |
| `@{read_file}` | Read contents of a file |
| `@{run_command}` | Execute a shell command |
| `@{web_search}` | Search the web via Tavily |

Tools that modify the filesystem (`create_file`, `delete_file`, `run_command`, `insert_edit_into_file`) require approval by default. `run_command` and `delete_file` are excluded from YOLO mode. Approvals are per-chat-buffer and per-tool — approving in one chat does not affect another.

MCP servers expose additional tools prefixed `@{mcp:*}`.

**Rules:**

Rules files (like `CLAUDE.md`, `AGENTS.md`, `.cursorrules`) are automatically loaded into new chat buffers. Use the `/rules` slash command to add more rule groups. `gM` clears all rules from the chat buffer. Rules can contain system prompts, file references, and arbitrary instruction text.

---

## Status panel

`<leader>cs` opens a floating panel showing every provider option for both inline and chat scopes. It is the fastest way to inspect and change your configuration.

The panel is interactive:
- `j`/`k` or arrow keys — navigate rows
- `<CR>` — enter edit mode on the current row
- `h`/`l` — cycle through values while editing
- `<CR>` again — commit the change (or `<Esc>`/`q` to cancel)
- `q` or `<Esc>` — close the panel

Provider rows show the current provider and, for inline, a transport reach marker: `(tool-free)` or `(can-read-repo)`.

Changes apply immediately:
- **Inline scope** — updates stored defaults and drains the connection pool so the next request uses the new provider/model
- **Chat scope** — updates stored defaults AND applies the change to the focused chat's live session

The panel rebuilds its rows when refocused, so if something changed outside the panel (e.g. you switched the focused chat to a different provider), the next time you look at it, it shows the current state. While a row is being edited, this refresh is skipped so your edit is not disrupted.

---

## Action palette

`<leader>ca` or `:CodeCompanionActions` opens CodeCompanion's action palette. This gives quick access to:

- **Chat** — open a new chat buffer
- **Open Chats** — jump to any open chat buffer
- **Built-in prompts**: Generate commit message, Explain code, Explain LSP diagnostics, Fix code, Generate unit tests
- **Chat with rules** — start a chat with specific rule groups loaded
- **Workflows** — run agentic workflows

These prompts can also be called from the command-line with their alias: `:CodeCompanion /explain`, `:CodeCompanion /fix`, `:CodeCompanion /commit`, `:CodeCompanion /lsp`, `:CodeCompanion /tests`.

---

## Code review

Code review lets you leave comments on agent-produced code and send them back as a batch, with full file/line/code context. It works with ACP agents, built-in tools, and even CLI agents running outside Neovim.

**Workflow:**
1. `:CodeCompanionCodeReview Start` — marks the baseline (what you'll review against)
2. Let the agent work
3. `:CodeCompanionCodeReview` — opens agent changes in the quickfix list
4. Navigate with `]q`/`[q`. Press `d` to diff a hunk, `c` to comment, `a` to accept, `x` to ignore the file
5. `:CodeCompanionCodeReview Comment` — leave a comment on the current line or visual selection
6. In a chat buffer, type `#{code_review}` and send — all pending comments are sent to the LLM with full context
7. `:CodeCompanionCodeReview Approve` — advance the baseline; the next review only shows new changes

For agents outside CodeCompanion, use `:CodeCompanionCodeReview Share` to export the review to a file and paste its path into the agent.

---

## CLI interaction

`:CodeCompanionCLI` opens a terminal buffer running a CLI agent (e.g. Claude Code). You can send prompts, add context, and interact with the agent from within Neovim.

- `:CodeCompanionCLI <prompt>` — send a prompt to the last CLI instance (or create one)
- `:CodeCompanionCLI! <prompt>` — send and auto-submit (agent starts immediately)
- `:CodeCompanionCLI agent=<name> <prompt>` — use a specific agent
- `:CodeCompanionCLI Ask` — open a rich prompt input buffer with completion support

The prompt input buffer supports `#{editor_context}` references, the `/buffer` and `/file` slash commands (which insert `@path` references instead of file contents), and scrollable history with `<Up>`/`<Down>`. Write with `:w` to send, `:w!` to send and submit.

The special `#{this}` context resolves to the current buffer in normal mode, or the visual selection + file reference in visual mode.

---

## Debug commands

Two developer commands for inspecting the connection pool:

- `:AiPoolStatus` — shows a table of live ACP connections: provider, connection id, primary vs overflow, state, age, idle time, busy/idle status, and session id. Also shows queued request depth per provider. Nothing should be spawned at startup — an empty panel confirms lazy loading
- `:AiDebugSend {provider} {prompt}` — sends a raw prompt through the pool and opens the full reply in a scratch buffer. No parsing, no placement, no buffer mutation. Useful for isolating transport problems from parsing/placement bugs. Works with ACP providers only (claude, opencode)

---

## Built-in commands

These CodeCompanion commands remain available alongside the custom features above:

- `:CodeCompanionChat` — open a chat buffer (uses claude by default)
- `:CodeCompanionChat Toggle` — toggle the last chat
- `:CodeCompanionChat <prompt>` — open a chat and send a prompt
- `:CodeCompanionChat adapter=<name>` — open with a specific adapter
- `:CodeCompanionChat Add` — add visual selection to the current chat
- `:CodeCompanionChat Changes` — open quickfix of files changed by the LLM
- `:CodeCompanionChat RefreshCache` — refresh conditional elements in the chat
- `:CodeCompanion` — built-in inline (uses ollama cloud by default, superseded by `<leader>ci`)
- `:CodeCompanionCmd` — generate a Neovim command (uses ollama cloud by default)
- `:CodeCompanionActions Refresh` — refresh the action palette and prompt library
- `:checkhealth codecompanion` — check dependencies and log file location
