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
		local prov, model, title
		local ok, palette = pcall(function()
			return require("catppuccin.palettes").get_palette()
		end)
		if ok and palette then
			prov = palette.mauve
			model = palette.pink
			title = palette.blue
		else
			prov = "#94e2d5" -- teal — screams "fallback"
			model = "#94e2d5"
			title = "#c6a0f6" -- mauve
		end

		vim.api.nvim_set_hl(0, "AiWinBarProvider", { fg = prov, bg = "NONE" })
		vim.api.nvim_set_hl(0, "AiWinBarModel", { fg = model, bg = "NONE" })
		vim.api.nvim_set_hl(0, "AiWinBarTitle", { fg = title, bg = "NONE" })
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
---@return table|nil conn, string|nil provider, boolean|nil spawned
local function session_connection()
	-- Try an existing chat's ACP connection first
	for _, bufnr in ipairs(_G.codecompanion_buffers or {}) do
		local chat = require("codecompanion.interactions.chat").buf_get_chat(bufnr)
		local conn = chat and chat.acp_connection
		if conn and conn:is_ready() and conn.session_id then
			local name = chat.adapter and chat.adapter.name
			if name == "claude_code" or name == "opencode" then
				return conn, name
			end
		end
	end

	local providers = require("ai.providers")
	local adapters = require("codecompanion.adapters")
	local ACP = require("codecompanion.acp")

	-- Try claude first, then opencode
	for _, provider in ipairs({ "claude", "opencode" }) do
		local name = providers.acp_adapter(provider)
		if name then
			local adapter = adapters.resolve(name)
			if adapter then
				local conn = ACP.new({ adapter = adapter })
				if conn:connect_and_authenticate() then
					return conn, name, true
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
---@return { sessionId: string, title: string, updatedAt: string, cwd: string }[]
local function resumable_sessions()
	if M._cached_sessions then
		return M._cached_sessions
	end

	local root = git_root()
	if not root then
		return {}
	end

	local conn, provider, spawned = session_connection()
	if not conn then
		return {}
	end

	local raw = conn:session_list({ max_sessions = 500 })
	local filtered = {}
	for _, s in ipairs(raw) do
		if s.cwd and vim.startswith(s.cwd, root) then
			table.insert(filtered, {
				sessionId = s.sessionId,
				title = s.title or s.sessionId,
				updatedAt = s.updatedAt or "",
				cwd = s.cwd or "",
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

---Live nvim chats, sorted most-recent first.
---@return { bufnr: number, title: string, session_id: string|nil }[]
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
			table.insert(out, { bufnr = bufnr, title = title, session_id = session_id, provider = provider, model = model })
		end
	end
	return out
end

--=============================================================================
-- Picker
--=============================================================================

---@return table
local function picker()
	local live = live_chats()
	local sessions = resumable_sessions()

	local entries = {}

	local live_session_ids = {}
	for _, chat in ipairs(live) do
		if chat.session_id then
			live_session_ids[chat.session_id] = true
		end
	end

	-- Live chats first
	for _, chat in ipairs(live) do
		local title = chat.title
		local provider = chat.provider
		local model = chat.model

		local prefix = "💬 "
		local sep = "  "
		local dot = " · "
		local full = prefix .. title .. sep .. provider .. dot .. model

		-- 0-based byte offsets for highlight ranges
		local t_start = #prefix
		local t_end = t_start + #title
		local p_start = t_end + #sep
		local p_end = p_start + #provider
		local m_start = p_end + #dot
		local m_end = m_start + #model

		local highlights = {
			{ { t_start, t_end }, "AiWinBarTitle" },
			{ { p_start, p_end }, "AiWinBarProvider" },
			{ { m_start, m_end }, "AiWinBarModel" },
		}

		-- Bind per-iteration: the closure below captures the current
		-- iteration's full/highlights, not the loop variable's final value.
		local make_display = function() return full, highlights end

		table.insert(entries, {
			value = chat,
			ordinal = "1" .. chat.title,
			display = make_display,
			kind = "live",
		})
	end

	-- Resumable sessions
	for _, s in ipairs(sessions) do
		if not live_session_ids[s.sessionId] then
			table.insert(entries, {
				value = s,
				ordinal = "2" .. s.title .. (s.updatedAt or ""),
				display = "📋 " .. s.title .. "  " .. relative_time(s.updatedAt),
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

---Restore a past session into a fresh chat.
---@param entry table
local function restore_session(entry)
	local Chat = require("codecompanion.interactions.chat")
	local providers = require("ai.providers")
	local adapters = require("codecompanion.adapters")

	-- Resolve adapter from chat provider defaults, same as resolve_chat_adapter in chat.lua
	local sel = providers.current("chat")
	if not sel or not sel.provider then
		return vim.notify("[ai] no chat provider selected", vim.log.levels.WARN)
	end
	local adapter
	if sel.provider == "ollama" then
		local name = providers.http_adapter("chat")
		adapter = adapters.resolve(name)
	else
		local adapter_name = providers.acp_adapter(sel.provider)
		if not adapter_name then
			return vim.notify("[ai] no ACP adapter for " .. sel.provider, vim.log.levels.WARN)
		end
		local session_opts = {}
		local spec = providers.providers[sel.provider]
		local opts = sel.opts or {}
		if spec then
			for _, key in ipairs(spec.chat_options or {}) do
				local option = (spec.options or {})[key]
				local value = providers.resolve_chat_option_value(sel.provider, key, opts[key])
				if option and option.category and value then
					session_opts[option.category] = value
				end
			end
		end
		adapter = adapters.resolve(adapter_name, { session_config_options = session_opts })
		if adapter and sel.provider == "opencode" and adapter.env then
			adapter.env.OPENCODE_PERMISSION = nil
		end
	end
	if not adapter then
		return vim.notify("[ai] could not resolve chat adapter", vim.log.levels.ERROR)
	end

	local chat = Chat.new({
		adapter = adapter,
		buffer_context = { bufnr = api.nvim_get_current_buf() },
	})
	if not chat then
		return
	end

	-- We need an ACP connection on this chat to load the session.
	-- Chat.new doesn't establish it until first submit, but we can create
	-- one through the ACP handler pattern.
	local ACP = require("codecompanion.acp")
	local conn = ACP.new({ adapter = adapter, chat = chat })
	if not conn:connect_and_authenticate() then
		return vim.notify("[ai] could not connect to restore session", vim.log.levels.ERROR)
	end

	local updates = {}
	local ok = conn:load_session(entry.sessionId, {
		on_session_update = function(update)
			table.insert(updates, update)
		end,
	})

	if not ok then
		conn:disconnect()
		return vim.notify("[ai] failed to load session", vim.log.levels.ERROR)
	end

	-- Swap the chat's connection to this one so the session is live. Chat.new's
	-- own eager auto-connect (scheduled via vim.schedule) can race with the
	-- vim.wait busy-wait above and assign its own connection to
	-- chat.acp_connection first; disconnect that orphan before overwriting it,
	-- or it leaks its subprocess for the rest of the nvim session.
	if chat.acp_connection then
		pcall(chat.acp_connection.disconnect, chat.acp_connection)
	end
	chat.acp_connection = conn
	conn.chat = chat

	local acp_commands = require("codecompanion.interactions.chat.acp.commands")
	acp_commands.link_buffer_to_session(chat.bufnr, conn.session_id)

	require("codecompanion.interactions.chat.acp.render").restore_session(chat, updates)

	local sel = providers.current("chat")
	chat._ai_provider = sel.provider
	chat._ai_model = tostring(sel.opts.model)

	if entry.title then
		chat:set_title(entry.title)
	end

	-- Session is now live; drop the stale cache so it stops appearing
	-- under "resumable sessions" alongside its new live-chat entry.
	M.clear_cache()
end

---Open the Telescope picker.
function M.open()
	local ok, _ = pcall(require, "telescope")
	if not ok then
		return vim.notify("[ai] telescope is required for the chat list", vim.log.levels.ERROR)
	end

	ensure_highlights()

	local entries = picker()

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local sorters = require("telescope.sorters")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	pickers
		.new({}, {
			prompt_title = "Chats & Sessions",
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

				-- CTRL-d: close a single chat
				map({ "i", "n" }, "<C-d>", function()
					local selection = action_state.get_selected_entry()
					if not selection or selection.kind ~= "live" then
						return
					end
					local entry = selection.value
					if entry.bufnr and api.nvim_buf_is_valid(entry.bufnr) then
						local chat = require("codecompanion.interactions.chat").buf_get_chat(entry.bufnr)
						if chat then
							chat:close()
						else
							pcall(api.nvim_buf_delete, entry.bufnr, { force = true })
						end
					end
					-- Refresh the picker
					entries = picker()
					local current_picker = action_state.get_current_picker(prompt_bufnr)
					if current_picker then
						current_picker:refresh(
							finders.new_table({ results = entries, entry_maker = function(e) return e end }),
							{}
						)
					end
				end)

				return true
			end,
		})
		:find()
end

---Clear the cached session list; the next open re-queries.
function M.clear_cache()
	M._cached_sessions = nil
end

return M
