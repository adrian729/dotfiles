-- Chat list: Telescope picker with live chats and resumable sessions, including
-- sessions started outside nvim. Filtered by git root so sessions don't vanish
-- when nvim is opened in a subdirectory.

local M = {}

local api = vim.api

--=============================================================================
-- Catppuccin Mocha highlights — same groups the winbar defines
--=============================================================================

local hl_ready = false

local function ensure_highlights()
	if hl_ready then
		return
	end
	hl_ready = true

	vim.schedule(function()
		local prov, model, title, ready, starting, dead, current, dim
		local ok, palette = pcall(function()
			return require("catppuccin.palettes").get_palette()
		end)
		if ok and palette then
			prov = palette.mauve
			model = palette.pink
			title = palette.blue
			ready = palette.green
			starting = palette.yellow
			dead = palette.red
			current = palette.lavender
			dim = palette.overlay1
		else
			prov = "#94e2d5" -- teal — screams "fallback"
			model = "#94e2d5"
			title = "#c6a0f6" -- mauve
			ready = "#a6e3a1"
			starting = "#f9e2af"
			dead = "#f38ba8"
			current = "#b4befe"
			dim = "#7f849c"
		end

		vim.api.nvim_set_hl(0, "AiWinBarProvider", { fg = prov, bg = "NONE" })
		vim.api.nvim_set_hl(0, "AiWinBarModel", { fg = model, bg = "NONE" })
		vim.api.nvim_set_hl(0, "AiWinBarTitle", { fg = title, bg = "NONE" })
		vim.api.nvim_set_hl(0, "AiListReady", { fg = ready, bg = "NONE" })
		vim.api.nvim_set_hl(0, "AiListStarting", { fg = starting, bg = "NONE" })
		vim.api.nvim_set_hl(0, "AiListDead", { fg = dead, bg = "NONE" })
		vim.api.nvim_set_hl(0, "AiListCurrent", { fg = current, bg = "NONE", bold = true })
		vim.api.nvim_set_hl(0, "AiListDim", { fg = dim, bg = "NONE" })
	end)
end

--=============================================================================
-- Helpers
--=============================================================================

---The git root of the current working directory, cached per nvim session.
---@return string|nil
local function git_root()
	if M._git_root ~= nil then
		return M._git_root
	end
	local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
	if not handle then
		M._git_root = false
		return nil
	end
	local result = handle:read("*a")
	handle:close()
	if result and result ~= "" then
		M._git_root = vim.trim(result)
	else
		M._git_root = false
	end
	return M._git_root ~= false and M._git_root or nil
end

---A relative timestamp like "(2m ago)".
---@param iso string ISO-8601 timestamp
---@return string
local function relative_time(iso)
	local ts = os.time()
	local parts = {}
	local function push(val, unit)
		if val > 0 then
			table.insert(parts, val .. unit)
		end
	end
	-- Simple parse: "2024-01-15T10:30:00Z"
	local year, month, day, hour, min, sec =
		iso:match("(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
	if not year then
		return ""
	end
	local session_time = os.time({
		year = tonumber(year),
		month = tonumber(month),
		day = tonumber(day),
		hour = tonumber(hour),
		min = tonumber(min),
		sec = tonumber(sec),
	})
	local delta = math.max(0, ts - session_time)
	if delta < 60 then
		return "just now"
	end
	local minutes = math.floor(delta / 60)
	if minutes < 60 then
		return minutes .. "m ago"
	end
	local hours = math.floor(minutes / 60)
	if hours < 24 then
		return hours .. "h ago"
	end
	local days = math.floor(hours / 24)
	if days < 30 then
		return days .. "d ago"
	end
	return math.floor(days / 30) .. "mo ago"
end

---Acquire a connection capable of listing sessions. Prefers a live chat's
---connection; falls back to spawning one through the pool's adapter resolution.
---@param opts? { no_spawn?: boolean, provider?: string } no_spawn: reuse a live chat's
---connection or give up. For repeated polling, where spawning an agent per attempt would
---cost a subprocess and a blocking handshake each time. provider: insist on an agent that
---can see a particular session — one agent's store is not another's, so a session listed
---by claude cannot be loaded or deleted over an opencode connection.
---@return table|nil conn, string|nil provider, boolean|nil spawned
local function session_connection(opts)
	opts = opts or {}

	-- Try an existing chat's ACP connection first
	for _, bufnr in ipairs(_G.codecompanion_buffers or {}) do
		local chat = require("codecompanion.interactions.chat").buf_get_chat(bufnr)
		local conn = chat and chat.acp_connection
		if conn and conn:is_ready() and conn.session_id then
			local name = chat.adapter and chat.adapter.name
			if name == "claude_code" or name == "opencode" then
				-- Report the ai.providers key rather than the CodeCompanion adapter
				-- name — callers feed it back into provider-keyed lookups.
				local key = chat._ai_provider or (name == "claude_code" and "claude" or "opencode")
				if not opts.provider or opts.provider == key then
					return conn, key
				end
			end
		end
	end

	if opts.no_spawn then
		return nil, nil
	end

	local providers = require("ai.providers")
	local adapters = require("codecompanion.adapters")
	local ACP = require("codecompanion.acp")

	-- The requested agent, or claude first and opencode second when it makes no difference
	for _, provider in ipairs(opts.provider and { opts.provider } or { "claude", "opencode" }) do
		local name = providers.acp_adapter(provider)
		if name then
			local adapter = adapters.resolve(name)
			if adapter then
				local conn = ACP.new({ adapter = adapter })
				if conn:connect_and_authenticate() then
					return conn, provider, true
				else
					-- connect_and_authenticate can fail after the child process has
					-- already spawned (e.g. initialize RPC or auth failure); avoid
					-- leaking that subprocess before trying the next provider.
					pcall(conn.disconnect, conn)
				end
			end
		end
	end

	return nil, nil
end

---Fetch and cache resumable sessions, filtered by git root.
---@param opts? { no_spawn?: boolean } passed through to session_connection
---@return { sessionId: string, title: string, updatedAt: string, cwd: string, provider: string }[]
local function resumable_sessions(opts)
	if M._cached_sessions then
		return M._cached_sessions
	end

	local root = git_root()
	if not root then
		return {}
	end

	local conn, provider, spawned = session_connection(opts)
	if not conn then
		return {}
	end

	local raw = conn:session_list({ max_sessions = 500 })
	-- A name the user gave the session outranks the agent's own summary of it, which is
	-- what session/list reports and what it would otherwise be shown under.
	local renamed = require("ai.chat").saved_titles()
	local filtered = {}
	for _, s in ipairs(raw) do
		if s.cwd and vim.startswith(s.cwd, root) then
			table.insert(filtered, {
				sessionId = s.sessionId,
				title = renamed[s.sessionId] or s.title or s.sessionId,
				updatedAt = s.updatedAt or "",
				cwd = s.cwd or "",
				-- The agent that listed the session is the one that can load it
				provider = provider,
			})
		end
	end

	table.sort(filtered, function(a, b)
		return a.updatedAt > b.updatedAt
	end)

	M._cached_sessions = filtered
	if spawned and conn then
		pcall(conn.disconnect, conn)
	end

	return filtered
end

-- How alive a chat's agent is. A chat buffer existing says nothing about this: startup
-- restores spend a second or two handshaking, and a crashed agent leaves the buffer
-- behind intact, so "there is a chat here" and "you can send it a message" are different
-- facts and the list shows both.
local STATE = {
	ready = { marker = "●", hl = "AiListReady", label = "ready" },
	starting = { marker = "◌", hl = "AiListStarting", label = "starting" },
	dead = { marker = "✕", hl = "AiListDead", label = "agent gone" },
	none = { marker = "·", hl = "AiListDim", label = "no agent" },
}

---Classify a chat's agent connection.
---@param chat table|nil
---@return "ready"|"starting"|"dead"|"none"
local function chat_state(chat)
	if not chat then
		return "none"
	end
	-- Only ACP chats have an agent process at all; an ollama chat is plain HTTP.
	if not (chat.adapter and chat.adapter.type == "acp") then
		return "none"
	end

	local conn = chat.acp_connection
	if not conn then
		-- Chat.new schedules the connection, so this is the first instant of a new chat
		return "starting"
	end
	if conn:is_connected() then
		return "ready"
	end
	-- handle_process_exit clears adapter_modified but leaves the handle set, which is what
	-- separates an agent that died from one that has not finished starting.
	if conn._state and conn._state.handle ~= nil and conn.adapter_modified == nil then
		return "dead"
	end
	return "starting"
end

---Live nvim chats, in the order the plugin tracks them.
---@return { bufnr: number, title: string, session_id: string|nil, provider: string, model: string, state: string, visible: boolean }[]
local function live_chats()
	local out = {}
	local seen = {}
	for _, bufnr in ipairs(_G.codecompanion_buffers or {}) do
		if api.nvim_buf_is_valid(bufnr) and not seen[bufnr] then
			seen[bufnr] = true
			local chat = require("codecompanion.interactions.chat").buf_get_chat(bufnr)
			local title = (chat and chat.title) or (api.nvim_buf_get_name(bufnr):match("([^/]+)$") or "chat")
			local session_id = chat and chat.acp_connection and chat.acp_connection.session_id
			local provider = (chat and chat._ai_provider) or "?"
			local model = (chat and chat._ai_model) or "?"
			table.insert(out, {
				bufnr = bufnr,
				title = title,
				session_id = session_id,
				provider = provider,
				model = model,
				state = chat_state(chat),
				visible = #vim.fn.win_findbuf(bufnr) > 0,
			})
		end
	end
	return out
end

--=============================================================================
-- Picker
--=============================================================================

---Assemble a display line from {text, highlight} segments. Telescope wants byte offsets,
---and the markers below are multibyte, so the offsets are accumulated from the segments
---rather than written out by hand.
---@param segments { [1]: string, [2]: string|nil }[]
---@return string text, table highlights
local function render(segments)
	local parts, highlights, offset = {}, {}, 0
	for _, seg in ipairs(segments) do
		local text = seg[1]
		if seg[2] and text ~= "" then
			table.insert(highlights, { { offset, offset + #text }, seg[2] })
		end
		table.insert(parts, text)
		offset = offset + #text
	end
	return table.concat(parts), highlights
end

---@param opts? { no_spawn?: boolean, current_buf?: number } current_buf: the chat to mark,
---captured by the caller before the picker took focus
---@return table
local function picker(opts)
	opts = opts or {}
	local live = live_chats()
	local sessions = resumable_sessions(opts)

	local entries = {}

	local live_session_ids = {}
	for _, chat in ipairs(live) do
		if chat.session_id then
			live_session_ids[chat.session_id] = true
		end
	end

	-- Live chats first
	for _, chat in ipairs(live) do
		local is_current = opts.current_buf ~= nil and chat.bufnr == opts.current_buf
		local state = STATE[chat.state] or STATE.none

		-- The state marker earns its column: a chat can be listed and still not be able to
		-- take a message. Anything other than ready is spelled out, since a coloured glyph
		-- alone does not say what is wrong.
		local note = ""
		if chat.state ~= "ready" then
			note = ("  (%s)"):format(state.label)
		elseif not chat.visible then
			note = "  (hidden)"
		end

		local text, highlights = render({
			{ is_current and "▶ " or "  ", is_current and "AiListCurrent" or nil },
			{ state.marker .. " ", state.hl },
			{ chat.title, is_current and "AiListCurrent" or "AiWinBarTitle" },
			{ "  " },
			{ chat.provider, "AiWinBarProvider" },
			{ " · " },
			{ chat.model, "AiWinBarModel" },
			{ note, "AiListDim" },
		})

		-- Bind per-iteration: the closure below captures the current
		-- iteration's text/highlights, not the loop variable's final value.
		local make_display = function()
			return text, highlights
		end

		-- The leading digit is what keeps the current chat on top, and live chats above
		-- stored sessions, once a filter is typed and the sorter starts ranking.
		local entry = {
			value = chat,
			ordinal = (is_current and "0" or "1") .. chat.title,
			display = make_display,
			kind = "live",
		}
		-- With an empty prompt every entry scores the same, so the sorter leaves them in
		-- finder order and the ordinal alone would not put the current chat first. Hoist it.
		if is_current then
			table.insert(entries, 1, entry)
		else
			table.insert(entries, entry)
		end
	end

	-- Resumable sessions. Aligned with the live entries' marker column so both sections
	-- read as one list, and dimmed: there is no agent behind these until you open one.
	for _, s in ipairs(sessions) do
		if not live_session_ids[s.sessionId] then
			local text, highlights = render({
				{ "  ○ ", "AiListDim" },
				{ s.title },
				{ "  " .. relative_time(s.updatedAt), "AiListDim" },
			})
			table.insert(entries, {
				value = s,
				ordinal = "2" .. s.title .. (s.updatedAt or ""),
				display = function()
					return text, highlights
				end,
				kind = "session",
			})
		end
	end

	return entries
end

---Focus a live chat buffer.
---@param entry table
local function focus_live(entry)
	if not api.nvim_buf_is_valid(entry.bufnr) then
		return vim.notify("[ai] that chat buffer is gone", vim.log.levels.WARN)
	end
	local chat = require("codecompanion.interactions.chat").buf_get_chat(entry.bufnr)
	if chat and chat.ui then
		chat.ui:open()
		if chat.ui.winnr and api.nvim_win_is_valid(chat.ui.winnr) then
			api.nvim_set_current_win(chat.ui.winnr)
		else
			api.nvim_set_current_buf(entry.bufnr)
		end
	else
		vim.cmd("buffer " .. entry.bufnr)
	end
end

---Restore a past session into a fresh chat. Shares ai.chat's implementation with
---the startup restore, which waits for the chat's own connection instead of
---spawning a second one alongside it.
---@param entry table
local function restore_session(entry)
	require("ai.chat").restore_session({
		session_id = entry.sessionId,
		title = entry.title,
		provider = entry.provider,
	})

	-- Session is now live; drop the stale cache so it stops appearing
	-- under "resumable sessions" alongside its new live-chat entry.
	M.clear_cache()
end

---Rename a stored session that has no chat open on it. Nothing is sent to the agent: it
---names sessions from its own summary of the conversation and offers no way to override
---that over ACP, so the chosen name is kept here and applied wherever the session is
---shown or reopened.
---@param entry table
local function rename_stored_session(entry)
	vim.ui.input({ prompt = "Rename session: ", default = entry.title }, function(input)
		local name = input and vim.trim(input) or ""
		if name == "" or name == entry.title then
			return
		end
		require("ai.chat").set_saved_title(entry.sessionId, name)
		M.clear_cache()
		vim.notify(("[ai] renamed to %s"):format(name), vim.log.levels.INFO)
	end)
end

---Delete a stored session that has no chat open on it, agent-side copy included.
---@param entry table
local function delete_stored_session(entry)
	local question = ("Delete %s and its saved transcript? This cannot be undone."):format(entry.title)
	if vim.fn.confirm(question, "&Delete\n&Cancel", 2) ~= 1 then
		return
	end

	-- Insist on the agent that listed the session: only it can see the session's file.
	local conn, _, spawned = session_connection({ provider = entry.provider })
	if not conn then
		return vim.notify(
			("[ai] no %s connection to delete the session with"):format(tostring(entry.provider)),
			vim.log.levels.ERROR
		)
	end

	local deleted = require("ai.chat").delete_session(entry.sessionId, conn)
	if spawned then
		pcall(conn.disconnect, conn)
	end
	if deleted then
		M.clear_cache()
		vim.notify(("[ai] deleted %s"):format(entry.title), vim.log.levels.INFO)
	end
end

local PROMPT_TITLE = "Chats & Sessions"
local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

---Track the startup restore from inside an open picker: spin in the prompt border while
---chats are still coming back and pull them in as they land. Without this the picker is
---simply empty for the first seconds of a session, which reads as "you have no chats"
---rather than "not yet" — the chats only register as buffers once their staggered
---restore fires.
---@param p table The live Telescope picker
---@param rebuild fun(p: table) Re-run the finder against the current chat list
local function follow_restores(p, rebuild)
	local chat = require("ai.chat")
	if not chat.restore_progress() then
		return
	end

	local frame = 1
	local last_done = -1

	local function tick()
		-- The picker is gone the moment its prompt buffer is: nothing left to update.
		if not (p.prompt_bufnr and api.nvim_buf_is_valid(p.prompt_bufnr)) then
			return
		end

		local progress = chat.restore_progress()
		local title = PROMPT_TITLE
		if progress then
			title = ("%s  %s restoring %d/%d"):format(PROMPT_TITLE, SPINNER[frame], progress.done, progress.total)
			frame = frame % #SPINNER + 1
		end
		pcall(function()
			p.layout.prompt.border:change_title(title)
		end)

		-- Rebuild only when the count moves, so a picker being typed into is not
		-- reset ten times a second. `math.huge` fires the final rebuild once the
		-- batch is finished, catching whatever the last restore added.
		local done = progress and progress.done or math.huge
		if done ~= last_done then
			last_done = done
			rebuild(p)
		end

		if progress then
			vim.defer_fn(tick, 100)
		end
	end

	tick()
end

---Open the Telescope picker.
function M.open()
	local ok, _ = pcall(require, "telescope")
	if not ok then
		return vim.notify("[ai] telescope is required for the chat list", vim.log.levels.ERROR)
	end

	ensure_highlights()

	-- Resolved now, before Telescope's prompt buffer becomes the current one: the answer
	-- follows BufEnter, so asking again during a rebuild would give the prompt, not a chat.
	local current = require("ai.chat").current_chat()
	local current_buf = current and api.nvim_buf_is_valid(current.bufnr) and current.bufnr or nil

	local entries = picker({ current_buf = current_buf })

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local sorters = require("telescope.sorters")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local function rebuild(p, popts)
		entries = picker(vim.tbl_extend("keep", popts or {}, { current_buf = current_buf }))
		p:refresh(
			finders.new_table({
				results = entries,
				entry_maker = function(e)
					return e
				end,
			}),
			{ reset_prompt = false }
		)
	end

	local chat_picker = pickers
		.new({}, {
			prompt_title = PROMPT_TITLE,
			-- Telescope has no help overlay of its own, and these mappings are not
			-- guessable — one of them deletes a transcript for good.
			results_title = "▶ current   ● ready  ◌ starting  ✕ gone  ○ stored   │   <CR> open  <C-r> rename  <C-d> close  <C-x> delete",
			finder = finders.new_table({
				results = entries,
				entry_maker = function(e)
					return e
				end,
			}),
			sorter = sorters.get_substr_matcher(),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					if not selection then
						return
					end

					local entry = selection.value
					local kind = selection.kind

					actions.close(prompt_bufnr)

					if kind == "live" then
						focus_live(entry)
					elseif kind == "session" then
						restore_session(entry)
					end
				end)

				---The chat behind a live entry, or nil if its buffer has gone.
				local function selected_chat(entry)
					if not (entry.bufnr and api.nvim_buf_is_valid(entry.bufnr)) then
						return nil
					end
					return require("codecompanion.interactions.chat").buf_get_chat(entry.bufnr)
				end

				-- CTRL-d: close a live chat without touching its stored session, so it
				-- stays resumable from this same list. Only live entries have anything to
				-- close; <C-x> is the one that removes a session.
				map({ "i", "n" }, "<C-d>", function()
					local selection = action_state.get_selected_entry()
					if not selection or selection.kind ~= "live" then
						return
					end
					local chat = selected_chat(selection.value)
					if chat then
						chat:close()
					elseif selection.value.bufnr then
						pcall(api.nvim_buf_delete, selection.value.bufnr, { force = true })
					end
					local current_picker = action_state.get_current_picker(prompt_bufnr)
					if current_picker then
						rebuild(current_picker)
					end
				end)

				-- CTRL-r (or r from normal mode): rename. Works on a live chat and on a
				-- stored session alike — the name is remembered against the session ID
				-- either way, so it survives closing the chat and reopening it later.
				local function rename_selected()
					local selection = action_state.get_selected_entry()
					if not selection then
						return
					end
					-- The picker closes first: vim.ui.input over a picker fights it for the
					-- prompt, and the answer can land in the filter instead.
					actions.close(prompt_bufnr)
					if selection.kind == "live" then
						local chat = selected_chat(selection.value)
						if chat then
							require("ai.chat").rename(chat)
						end
					else
						rename_stored_session(selection.value)
					end
				end
				map({ "i", "n" }, "<C-r>", rename_selected)
				map("n", "r", rename_selected)

				-- CTRL-x: remove for good — the chat and the agent's own copy of the
				-- conversation, so it does not return as a resumable session. The picker
				-- closes first because the confirmation is a modal cmdline prompt.
				map({ "i", "n" }, "<C-x>", function()
					local selection = action_state.get_selected_entry()
					if not selection then
						return
					end
					actions.close(prompt_bufnr)
					if selection.kind == "live" then
						local chat = selected_chat(selection.value)
						if chat then
							require("ai.chat").delete(chat)
						end
					else
						delete_stored_session(selection.value)
					end
				end)

				return true
			end,
		})

	chat_picker:find()
	-- no_spawn: the polling rebuilds must not spawn an agent per tick just to list
	-- sessions. The restores bring up connections of their own, which these then borrow.
	follow_restores(chat_picker, function(p)
		rebuild(p, { no_spawn = true })
	end)
end

---Clear the cached session list; the next open re-queries.
function M.clear_cache()
	M._cached_sessions = nil
end

return M
