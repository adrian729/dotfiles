-- Chat surface: toggle, new with preset options, close-all, and the prose-float upgrade
-- that opens a chat pre-loaded with the exchange.
--
-- Chat connections stay out of the inline pool because a shared connection restoring
-- history would swallow inline updates — the session-loading branch (`_loading_session and
-- _on_session_update`, acp/init.lua:660) outranks `_active_prompt`.

local M = {}

local api = vim.api

local last_chat_buf = nil
local spinner_group
local pending_agents = {} -- bufnr → agent name, applied on first ChatSubmitted

--=============================================================================
-- Session persistence — restore chats on startup
--=============================================================================

local state_dir = vim.fn.stdpath("state") .. "/ai"
local state_file = state_dir .. "/open_chats.json"

---Track which sessions are currently open as chat buffers, with their provider.
local function open_session_ids()
	local list = {}
	for _, bufnr in ipairs(_G.codecompanion_buffers or {}) do
		if api.nvim_buf_is_valid(bufnr) then
			local chat = require("codecompanion.interactions.chat").buf_get_chat(bufnr)
			local sid = chat and chat.acp_connection and chat.acp_connection.session_id
			local prov = chat and chat._ai_provider
			if sid and prov then
				table.insert(list, { sessionId = sid, provider = prov })
			end
		end
	end
	return list
end

local function save_open_chats()
	local list = open_session_ids()
	if #list == 0 then
		return
	end
	vim.fn.mkdir(state_dir, "p")
	local ok, encoded = pcall(vim.json.encode, list)
	if ok then
		local f, err = io.open(state_file, "w")
		if f then
			f:write(encoded)
			f:close()
		end
	end
end

local function setup_persistence()
	local augroup = api.nvim_create_augroup("AiChatPersistence", { clear = true })

	api.nvim_create_autocmd("BufWipeout", {
		group = augroup,
		callback = function(args)
			if vim.tbl_contains(_G.codecompanion_buffers or {}, args.buf) then
				vim.defer_fn(save_open_chats, 50)
			end
		end,
	})

	api.nvim_create_autocmd("VimLeavePre", {
		group = augroup,
		callback = save_open_chats,
	})
end

--=============================================================================
-- Winbar styling — Catppuccin Mocha palette
--=============================================================================

local winbar_hl_ready = false

local function ensure_winbar_highlights()
	if winbar_hl_ready then
		return
	end
	winbar_hl_ready = true

	-- Catppuccin mocha palette, with fallback if the module isn't loaded yet
	local prov, model, title, dim, sep
	local ok, palette = pcall(function()
		return require("catppuccin.palettes").get_palette()
	end)
	if ok and palette then
		prov = palette.mauve
		model = palette.pink
		title = palette.blue
		dim = palette.surface1
		sep = palette.surface0
	else
		prov = "#94e2d5" -- teal — screams "fallback"
		model = "#94e2d5"
		title = "#c6a0f6" -- mauve
		dim = "#585b70"
		sep = "#45475a"
	end

	vim.api.nvim_set_hl(0, "AiWinBarProvider", { fg = prov, bg = "NONE" })
	vim.api.nvim_set_hl(0, "AiWinBarModel", { fg = model, bg = "NONE" })
	vim.api.nvim_set_hl(0, "AiWinBarTitle", { fg = title, bg = "NONE" })
	vim.api.nvim_set_hl(0, "AiWinBarDim", { fg = dim, bg = "NONE" })
	vim.api.nvim_set_hl(0, "AiWinBarSep", { fg = sep, bg = "NONE" })
end

--=============================================================================
-- Waiting indicator
--=============================================================================

local function ensure_spinner_group()
	if spinner_group then
		return
	end
	spinner_group = api.nvim_create_augroup("AiChatSpinner", { clear = true })

	api.nvim_create_autocmd("User", {
		group = spinner_group,
		pattern = "CodeCompanionChatSubmitted",
		callback = function(args)
			local data = args.data
			if not data or not data.bufnr then
				return
			end
			local bufnr = data.bufnr
			if not api.nvim_buf_is_valid(bufnr) then
				return
			end

			local chat = require("codecompanion.interactions.chat").buf_get_chat(bufnr)

			-- Claude agent: must be applied after the session exists (category = nil)
			local agent = pending_agents[bufnr]
			if agent then
				pending_agents[bufnr] = nil
				local conn = chat and chat.acp_connection
				if conn and conn.set_config_option then
					pcall(conn.set_config_option, conn, "agent", agent)
				end
			end

			-- An ACP submit that fails before a prompt exists — connection or session setup — still
			-- fires ChatSubmitted, but RequestFinished only ever comes from the prompt builder, so a
			-- spinner started here would never be stopped. That failure clears current_request
			-- synchronously (Chat:done, before the event fires), which is how we recognise it.
			if chat and not chat.current_request then
				return
			end

			local ui = require("ai.ui")
			local spinner = ui.progress(bufnr, function()
				return api.nvim_buf_line_count(bufnr) - 1
			end, "thinking…")
			api.nvim_buf_set_var(bufnr, "ai_chat_spinner", spinner)
		end,
	})

	api.nvim_create_autocmd("User", {
		group = spinner_group,
		pattern = "CodeCompanionRequestFinished",
		callback = function(args)
			local data = args.data
			local bufnr = data and data.bufnr
			if bufnr and api.nvim_buf_is_valid(bufnr) then
				local ok, spinner = pcall(api.nvim_buf_get_var, bufnr, "ai_chat_spinner")
				if ok and spinner then
					spinner:stop()
					pcall(api.nvim_buf_del_var, bufnr, "ai_chat_spinner")
				end
			end
		end,
	})

	-- A chat buffer that was deleted before its first submit never fires
	-- ChatSubmitted, so the agent entry would leak forever.
	api.nvim_create_autocmd("BufWipeout", {
		group = spinner_group,
		callback = function(args)
			pending_agents[args.buf] = nil
		end,
	})
end

--=============================================================================
-- Adapter resolution
--=============================================================================

---Post-resolution tweak: the opencode adapter in codecompanion.lua sets
---OPENCODE_PERMISSION denying writes — that is the inline defence and must not
---apply to chat sessions. Strip it here so the chat gets full tool access.
---@param adapter table
---@param provider string
local function strip_inline_defences(adapter, provider)
	if not adapter then
		return
	end
	if provider == "opencode" and adapter.env then
		adapter.env.OPENCODE_PERMISSION = nil
	end
end

local function resolve_chat_adapter()
	local providers = require("ai.providers")
	local adapters = require("codecompanion.adapters")
	local sel = providers.current("chat")

	if not sel or not sel.provider then
		return nil
	end

	if sel.provider == "ollama" then
		local name = providers.http_adapter("chat")
		local adapter = adapters.resolve(name)
		if not adapter then
			return nil
		end
		-- The stock schema reads from inline scope — redirect to chat
		if adapter.schema then
			if adapter.schema.model then
				adapter.schema.model.default = function()
					local current = providers.current("chat")
					return (current and current.opts or {}).model
				end
			end
			if adapter.schema.think then
				adapter.schema.think.default = function()
					local current = providers.current("chat")
					return (current and current.opts or {}).think == "on"
				end
			end
		end
		return adapter
	end

	local adapter_name = providers.acp_adapter(sel.provider)
	if not adapter_name then
		return nil
	end

	local session_opts = {}
	local spec = providers.providers[sel.provider]
	if not spec then
		return nil
	end
	local opts = sel.opts or {}

	for _, key in ipairs(spec.chat_options or {}) do
		local option = (spec.options or {})[key]
		local value = providers.resolve_chat_option_value(sel.provider, key, opts[key])
		if option and option.category and value then
			session_opts[option.category] = value
		end
	end

	local adapter = adapters.resolve(adapter_name, { session_config_options = session_opts })
	if not adapter then
		return nil
	end
	strip_inline_defences(adapter, sel.provider)
	return adapter
end

--=============================================================================
-- Public API
--=============================================================================

---A minimal buffer context carrying only the fields Chat.new accesses directly
---(bufnr). The full editor context (n module) is assembled by the plugin itself
---from args.context if the caller provides one.
---@return table
local function current_buffer_context()
	return { bufnr = api.nvim_get_current_buf() }
end

---Stash the claude agent so it is applied on the first ChatSubmitted. The agent
---option has category = nil and can only reach the session via conn:set_config_option,
---which needs the live session that does not exist at Chat.new time.
---@param bufnr number
local function stash_agent(bufnr)
	local providers = require("ai.providers")
	local sel = providers.current("chat")
	if sel and sel.provider == "claude" and sel.opts and sel.opts.agent and sel.opts.agent ~= "default" then
		pending_agents[bufnr] = sel.opts.agent
	end
end

---Post-creation guard: track the buffer, set an informative title, stash the agent, and
---record provider/model so the chat list can surface them without guessing from the adapter.
---@param chat table|nil
local function post_create(chat)
	if not chat then
		return
	end
	last_chat_buf = chat.bufnr
	stash_agent(chat.bufnr)

	local sel = require("ai.providers").current("chat")
	local model = tostring(sel.opts.model)
	local display = ("%s · %s"):format(sel.provider, model)
	pcall(chat.set_title, chat, display)

	chat._ai_provider = sel.provider
	chat._ai_model = model

	-- Winbar header — stays pinned at the top of every window showing this chat.
	-- BufFilePost fires when CodeCompanion auto-titles the chat (set_title → nvim_buf_set_name),
	-- so the title field updates within a second of the first response landing.
	ensure_winbar_highlights()

	local function winbar_text(bufnr)
		local chat_obj = require("codecompanion.interactions.chat").buf_get_chat(bufnr)
		local title = (chat_obj and chat_obj.title) or "untitled"
		local prov = chat_obj and chat_obj._ai_provider or sel.provider
		local mod = chat_obj and chat_obj._ai_model or model
		local D = "%#AiWinBarDim#"
		local P = "%#AiWinBarProvider#"
		local Mh = "%#AiWinBarModel#"
		local T = "%#AiWinBarTitle#"
		local S = "%#AiWinBarSep#"
		return {
			("  %s%s%s · %s%s%s   │   %s%s%s  "):format(P, prov, D, Mh, mod, D, T, title, D),
			S .. string.rep("─", 120),
		}
	end

	local function update_winbar(bufnr)
		if not api.nvim_buf_is_valid(bufnr) then
			return
		end
		local text = winbar_text(bufnr)
		for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
			local ok = pcall(function()
				vim.wo[win].winbar = text
			end)
			if not ok then
				pcall(function()
					vim.wo[win].winbar = text[1]
				end)
			end
		end
	end

	local augroup = api.nvim_create_augroup("AiChatWinbar" .. chat.bufnr, { clear = true })
	vim.defer_fn(function()
		update_winbar(chat.bufnr)
	end, 10) -- wait for the window to materialise

	api.nvim_create_autocmd("BufWinEnter", {
		group = augroup,
		buffer = chat.bufnr,
		callback = function()
			update_winbar(chat.bufnr)
		end,
	})
	api.nvim_create_autocmd("BufFilePost", {
		group = augroup,
		buffer = chat.bufnr,
		callback = function(args)
			update_winbar(args.buf)
		end,
	})
	api.nvim_create_autocmd("BufWipeout", {
		group = augroup,
		buffer = chat.bufnr,
		once = true,
		callback = function(args)
			for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
				vim.wo[win].winbar = nil
			end
			pcall(api.nvim_del_augroup_by_id, augroup)
		end,
	})
end

---Toggle the last chat buffer. Delegates to the plugin's own toggle, which
---tracks last_chat internally and is the authority on show/hide state — but
---only once a real chat exists. Without this guard, the plugin's own toggle
---creates a brand-new chat with adapter = nil when there is none, bypassing
---all of this repo's provider/model/effort/mode setup.
function M.toggle()
	local chat = require("codecompanion.interactions.chat").last_chat()
	if not chat or not api.nvim_buf_is_valid(chat.bufnr) then
		return M.new()
	end
	vim.cmd("CodeCompanionChat Toggle")
end

---Start a new chat with the current provider and its preset options.
---Extra keys (messages, auto_submit, etc.) are passed through to Chat.new.
---@param opts? table
function M.new(opts)
	opts = opts or {}
	ensure_spinner_group()

	local Chat = require("codecompanion.interactions.chat")
	local adapter = resolve_chat_adapter()
	if not adapter then
		return vim.notify("[ai] could not resolve adapter for chat", vim.log.levels.ERROR)
	end

	local chat = Chat.new(vim.tbl_extend("keep", { adapter = adapter, buffer_context = current_buffer_context() }, opts))
	post_create(chat)
end

---Close every chat buffer the plugin knows about.
function M.close_all()
	local closed = 0
	-- Snapshot before iterating: Chat:close() mutates codecompanion_buffers
	-- via table.remove, and ipairs over the live table would skip elements
	-- as later entries shift down into already-visited slots.
	local bufs = vim.list_extend({}, _G.codecompanion_buffers or {})
	for _, buf in ipairs(bufs) do
		if api.nvim_buf_is_valid(buf) then
			-- Route through Chat:close() so the acp_connection gets
			-- disconnected and codecompanion_buffers/chats bookkeeping stays
			-- in sync; a raw buf_delete would leak the subprocess and leave
			-- the stale bufnr behind.
			local chat = require("codecompanion.interactions.chat").buf_get_chat(buf)
			if chat then
				chat:close()
			else
				pcall(api.nvim_buf_delete, buf, { force = true })
			end
			closed = closed + 1
		end
	end
	if closed > 0 then
		vim.notify(("[ai] closed %d chat(s)"):format(closed), vim.log.levels.INFO)
	else
		vim.notify("[ai] no chats to close", vim.log.levels.INFO)
	end
end

---Stop the running request in the last active chat. Works from anywhere —
---the chat buffer doesn't need to be focused.
function M.stop()
	local chat = require("codecompanion.interactions.chat").last_chat()
	if not chat or not api.nvim_buf_is_valid(chat.bufnr) then
		return vim.notify("[ai] no chat to stop", vim.log.levels.INFO)
	end
	if chat.current_request or chat.tool_orchestrator then
		-- CodeCompanion's stop does not reliably fire RequestFinished, which is what
		-- clears our thinking spinner. Clear it here so the virtual text doesn't stay
		-- frozen on screen.
		local ok, spinner = pcall(api.nvim_buf_get_var, chat.bufnr, "ai_chat_spinner")
		if ok and spinner then
			spinner.stop()
			pcall(api.nvim_buf_del_var, chat.bufnr, "ai_chat_spinner")
		end
		chat:stop()
		vim.notify("[ai] stopped", vim.log.levels.INFO)
	else
		vim.notify("[ai] nothing in flight", vim.log.levels.INFO)
	end
end

---Rename the current chat. Prompts for a new title, sets it via CodeCompanion's
---set_title which also updates the buffer name, and the winbar follows via BufFilePost.
---@param chat? table Passed by the chat list to rename a specific entry.
function M.rename(chat)
	chat = chat or require("codecompanion.interactions.chat").buf_get_chat(api.nvim_get_current_buf())
	if not chat then
		chat = require("codecompanion.interactions.chat").last_chat()
	end
	if not chat or not api.nvim_buf_is_valid(chat.bufnr) then
		return vim.notify("[ai] no chat to rename", vim.log.levels.INFO)
	end

	local current = chat.title or ""
	vim.ui.input({ prompt = "Rename chat: ", default = current }, function(input)
		if input and vim.trim(input) ~= "" and vim.trim(input) ~= current then
			chat:set_title(vim.trim(input))
		end
	end)
end

---Open a chat pre-loaded with messages — the prose-float upgrade. The caller
---passes `messages` and any other Chat.new argument, and the adapter is resolved
---from the current chat provider selection.
---@param opts? table
function M.open_with_context(opts)
	opts = opts or {}
	ensure_spinner_group()

	local Chat = require("codecompanion.interactions.chat")
	local adapter = resolve_chat_adapter()
	if not adapter then
		return vim.notify("[ai] could not resolve adapter for chat", vim.log.levels.ERROR)
	end

	local chat_opts = vim.tbl_extend("keep", { adapter = adapter, buffer_context = current_buffer_context() }, opts)
	local chat = Chat.new(chat_opts)
	post_create(chat)
end

---Switch the chat provider and model. Mirror of inline.pick() for the chat scope.
function M.pick()
	local providers = require("ai.providers")
	local names = vim.tbl_keys(providers.providers)
	table.sort(names)

	vim.ui.select(names, { prompt = "Chat provider" }, function(provider)
		if not provider then
			return
		end

		local function commit(model, extra)
			providers.set_provider("chat", provider)
			for key, value in pairs(extra or {}) do
				providers.set_option("chat", key, value)
			end
			if model then
				providers.set_option("chat", "model", model)
			end
			local current = providers.current("chat")
			vim.notify(("[ai] chat → %s · %s"):format(provider, tostring(current.opts.model)))
		end

		local function choose_model(list, extra)
			vim.ui.select(list, { prompt = provider .. " model" }, function(model)
				if not model then
					return
				end
				commit(model, extra)
			end)
		end

		if provider == "opencode" then
			return choose_model(providers.opencode_models())
		end
		if provider == "claude" then
			return choose_model(providers.providers.claude.options.model.values)
		end

		vim.ui.select({ "cloud", "local" }, { prompt = "ollama endpoint" }, function(endpoint)
			if not endpoint then
				return
			end
			providers.ollama_models(endpoint, function(models, err)
				if not models then
					return vim.notify("[ai] " .. err, vim.log.levels.ERROR)
				end
				choose_model(models, { endpoint = endpoint })
			end)
		end)
	end)
end

setup_persistence()

return M
