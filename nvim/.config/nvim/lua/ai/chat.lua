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

			-- Claude agent: must be applied after the session exists (category = nil)
			local agent = pending_agents[bufnr]
			if agent then
				pending_agents[bufnr] = nil
				local chat = require("codecompanion.interactions.chat").buf_get_chat(bufnr)
				local conn = chat and chat.acp_connection
				if conn and conn.set_config_option then
					pcall(conn.set_config_option, conn, "agent", agent)
				end
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
		local value = opts[key]
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

---Post-creation guard: track the buffer and stash the agent.
---@param chat table|nil
local function post_create(chat)
	if not chat then
		return
	end
	last_chat_buf = chat.bufnr
	stash_agent(chat.bufnr)
end

---Toggle the last chat buffer. Delegates to the plugin's own toggle, which
---tracks last_chat internally and is the authority on show/hide state.
function M.toggle()
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
	for _, buf in ipairs(vim.g.codecompanion_buffers or {}) do
		if api.nvim_buf_is_valid(buf) then
			pcall(api.nvim_buf_delete, buf, { force = true })
			closed = closed + 1
		end
	end
	if closed > 0 then
		vim.notify(("[ai] closed %d chat(s)"):format(closed), vim.log.levels.INFO)
	else
		vim.notify("[ai] no chats to close", vim.log.levels.INFO)
	end
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

return M
