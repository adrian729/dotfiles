-- Inline refactoring (local ollama) + focused chat (Claude via ACP, no API key).
-- Agentic/multi-file work stays outside nvim (tmux popups: C-c claude, C-o opencode).

-- Local ollama models available on this machine.
local ollama_models = { "qwen3:30b", "qwen3-coder:30b", "qwen3:14b", "deepseek-r1:14b" }

-- INLINE: pick the ollama model (read live by the ollama_inline adapter; JSON always forced).
local function pick_ollama_model()
	vim.ui.select(ollama_models, { prompt = "Inline ollama model" }, function(choice)
		if choice then
			vim.g.ollama_inline_model = choice
			vim.notify("Inline ollama model → " .. choice)
		end
	end)
end

-- CHAT: open a NEW chat on a chosen backend (+ model). Each chat buffer is independent;
-- change a live chat's backend/model afterwards with `ga`. ACP backends (claude_code/opencode)
-- expose their models dynamically, so pick those via `ga` once the chat is open.
local function new_chat()
	vim.ui.select({ "claude_code", "ollama", "opencode" }, { prompt = "Chat backend" }, function(be)
		if not be then
			return
		end
		if be == "ollama" then
			vim.ui.select(ollama_models, { prompt = "ollama model" }, function(m)
				if m then
					vim.cmd("CodeCompanionChat adapter=ollama model=" .. m)
				end
			end)
		else
			vim.cmd("CodeCompanionChat adapter=" .. be) -- pick model with `ga` after it opens
		end
	end)
end

-- Toggle qwen3 reasoning for ollama (off = fast, on = higher quality). Read live per request.
local function toggle_ollama_think()
	vim.g.ollama_think = not vim.g.ollama_think
	vim.notify("ollama thinking → " .. (vim.g.ollama_think and "ON (slower)" or "OFF (fast)"))
end

-- Inline "waiting on ollama" spinner + busy guard (prevents stacking inline requests).
local Inline = { busy = false, timer = nil, win = nil, buf = nil, frame = 1, label = "" }
local SPIN = math.random() > 0.5 and { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
	or { "⠁", "⠂", "⠄", "⡀", "⡁", "⡂", "⡄", "⡈", "⡐", "⡠" }

local function spinner_stop()
	if Inline.timer then
		Inline.timer:stop()
		if not Inline.timer:is_closing() then
			Inline.timer:close()
		end
		Inline.timer = nil
	end
	if Inline.win and vim.api.nvim_win_is_valid(Inline.win) then
		vim.api.nvim_win_close(Inline.win, true)
	end
	Inline.win, Inline.buf = nil, nil
end

local function spinner_render()
	if not (Inline.buf and vim.api.nvim_buf_is_valid(Inline.buf)) then
		return
	end
	local text = " " .. SPIN[Inline.frame] .. " " .. Inline.label .. " "
	vim.api.nvim_buf_set_lines(Inline.buf, 0, -1, false, { text })
	local w = vim.fn.strdisplaywidth(text)
	if Inline.win and vim.api.nvim_win_is_valid(Inline.win) then
		vim.api.nvim_win_set_config(Inline.win, { relative = "cursor", row = 1, col = 0, width = w, height = 1 })
	else
		Inline.win = vim.api.nvim_open_win(Inline.buf, false, {
			relative = "cursor",
			row = 1,
			col = 0,
			width = w,
			height = 1,
			style = "minimal",
			border = "rounded",
			focusable = false,
			noautocmd = true,
		})
	end
end

local function spinner_start(label)
	spinner_stop()
	Inline.label = label
	Inline.frame = 1
	Inline.buf = vim.api.nvim_create_buf(false, true)
	spinner_render()
	Inline.timer = vim.uv.new_timer()
	Inline.timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			Inline.frame = (Inline.frame % #SPIN) + 1
			spinner_render()
		end)
	)
end

-- Appended to every inline prompt. `replace` swaps the ENTIRE selection, so the model must
-- return the whole selection with the edit applied — not just the changed part (otherwise the
-- rest of the selection gets deleted). Verified to keep unchanged lines verbatim.
local FULL_SELECTION_HINT = "IMPORTANT: return the COMPLETE selection with your change applied. "
	.. "Reproduce every other line EXACTLY as given; do not omit, summarize, shorten, or drop any unchanged lines."

-- Guarded inline trigger: refuse while a request is in flight. Collects the prompt, appends the
-- full-selection instruction, and runs :CodeCompanion with the visual range preserved.
local function inline_run()
	if Inline.busy then
		vim.notify("Inline busy — waiting on ollama (<leader>cx to reset)", vim.log.levels.WARN)
		return
	end
	local m = vim.fn.mode()
	local range
	if m == "v" or m == "V" or m == "\22" then
		vim.cmd("normal! \27") -- leave visual so the '< / '> marks are set
		range = { vim.fn.line("'<"), vim.fn.line("'>") }
	end
	vim.ui.input({ prompt = "Inline (ollama): " }, function(input)
		if not input or vim.trim(input) == "" then
			return
		end
		local prompt = input .. " " .. FULL_SELECTION_HINT
		vim.api.nvim_cmd({ cmd = "CodeCompanion", args = { prompt }, range = range }, {})
	end)
end

-- Manual unblock in case a request hangs and never fires its finish event.
local function inline_reset()
	Inline.busy = false
	spinner_stop()
	vim.notify("Inline unblocked")
end

-- Close (delete) all open CodeCompanion chat buffers.
local function close_all_chats()
	local n = 0
	for _, c in ipairs(require("codecompanion").buf_get_chat()) do
		if c.chat and c.chat.close then
			c.chat:close()
			n = n + 1
		end
	end
	vim.notify("Closed " .. n .. " chat(s)")
end

-- Best-effort read of a chat object's resolved model id.
local function chat_model(chat)
	local a = chat and chat.adapter
	if not a then
		return "?"
	end
	local m = a.model and (a.model.name or a.model) or (a.schema and a.schema.model and a.schema.model.default)
	if type(m) == "function" then
		local ok, v = pcall(m, a)
		m = ok and v or "?"
	end
	return tostring(m or "?")
end

-- Popup showing what each mode currently uses.
local function show_status()
	local cc = require("codecompanion")
	local cfg = require("codecompanion.config")
	local chat_default = cfg.config.interactions.chat.adapter

	-- current chat = this buffer if it's a chat, else the last-focused chat
	local this = cc.buf_get_chat and cc.buf_get_chat(vim.api.nvim_get_current_buf())
	local last = (not this) and cc.last_chat and cc.last_chat() or nil
	local active = this or last

	local lines = {
		"  CodeCompanion — current selection",
		"",
		string.format(
			"  Inline   ollama · %s · think %s",
			vim.g.ollama_inline_model,
			vim.g.ollama_think and "ON" or "OFF"
		),
		string.format("  Cmd      ollama · %s", vim.g.ollama_inline_model),
		string.format("  Chat     default: %s", chat_default),
	}
	if active then
		lines[#lines + 1] = string.format(
			"           %s chat: %s · %s",
			this and "this" or "last",
			active.adapter and active.adapter.name or "?",
			chat_model(active)
		)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "  cm model · ct think · cn new chat · ga (in chat) switch"

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	local w = width + 2
	local h = #lines
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - w) / 2),
		width = w,
		height = h,
		style = "minimal",
		border = "rounded",
		title = " AI ",
		title_pos = "center",
	})
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf })
	vim.keymap.set("n", "<esc>", "<cmd>close<cr>", { buffer = buf })
end

-- Factory for an ollama adapter pointed at the local server, with model/think read live
-- from globals. `overrides` is deep-merged (e.g. body.format for the inline JSON envelope).
local function ollama_adapter(overrides)
	return function()
		return require("codecompanion.adapters").extend(
			"ollama",
			vim.tbl_deep_extend("force", {
				env = { url = "http://localhost:11434" },
				schema = {
					model = {
						default = function()
							return vim.g.ollama_inline_model
						end,
					},
					think = {
						-- reasoning off by default (fast); toggle live via <leader>ct
						default = function()
							return vim.g.ollama_think == true
						end,
					},
					keep_alive = { default = "30m" }, -- keep the model warm between calls
					num_ctx = { default = 16384 }, -- ollama default is tiny; raise for real refactors
				},
			}, overrides or {})
		)
	end
end

return {
	{
		"olimorris/codecompanion.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
		keys = {
			{
				"<leader>cc",
				"<cmd>CodeCompanionChat Toggle<cr>",
				mode = { "n", "x" },
				desc = "CodeCompanion: toggle chat",
			},
			{
				"<leader>ca",
				"<cmd>CodeCompanionActions<cr>",
				mode = { "n", "x" },
				desc = "CodeCompanion: action palette",
			},
			{ "<leader>ci", inline_run, mode = { "n", "x" }, desc = "CodeCompanion: inline prompt" },
			{ "<leader>cx", inline_reset, desc = "CodeCompanion: unblock inline (reset busy)" },
			{ "<leader>cn", new_chat, desc = "CodeCompanion: new chat (pick backend)" },
			{ "<leader>cq", close_all_chats, desc = "CodeCompanion: close all chats" },
			{ "<leader>cm", pick_ollama_model, desc = "CodeCompanion: switch inline ollama model" },
			{ "<leader>ct", toggle_ollama_think, desc = "CodeCompanion: toggle ollama thinking" },
			{ "<leader>cs", show_status, desc = "CodeCompanion: status (what's selected)" },
		},
		config = function()
			-- Default inline model. Use the CODER model, not the qwen3 reasoning models
			-- (qwen3:14b/30b overthink and refuse trivial edits, and are minutes-slow). Switch
			-- at runtime via <leader>cm; note qwen3-coder:30b (20GB) may swap against `llm --code`.
			vim.g.ollama_inline_model = vim.g.ollama_inline_model or "qwen3-coder:30b"
			-- Reasoning off by default (fast inline); toggle at runtime via <leader>ct.
			if vim.g.ollama_think == nil then
				vim.g.ollama_think = false
			end

			-- Inline: spinner while ollama is thinking + block re-triggering until it returns.
			local grp = vim.api.nvim_create_augroup("CodeCompanionInlineSpinner", { clear = true })
			vim.api.nvim_create_autocmd("User", {
				group = grp,
				pattern = "CodeCompanionRequestStarted",
				callback = function(ev)
					local a = ev.data and ev.data.adapter
					if a and a.name == "ollama_inline" then
						Inline.busy = true
						spinner_start("ollama " .. (a.model or ""))
					end
				end,
			})
			vim.api.nvim_create_autocmd("User", {
				group = grp,
				pattern = { "CodeCompanionRequestFinished", "CodeCompanionInlineFinished" },
				callback = function(ev)
					local a = ev.data and ev.data.adapter
					if (not a) or a.name == "ollama_inline" then
						Inline.busy = false
						spinner_stop()
					end
				end,
			})

			-- Chat: "thinking" spinner while waiting for a reply (any backend — http or ACP).
			vim.api.nvim_create_autocmd("User", {
				group = grp,
				pattern = "CodeCompanionChatSubmitted",
				callback = function()
					spinner_start("thinking…")
				end,
			})
			vim.api.nvim_create_autocmd("User", {
				group = grp,
				pattern = "CodeCompanionChatDone",
				callback = function()
					spinner_stop()
				end,
			})

			require("codecompanion").setup({
				opts = { log_level = "DEBUG" }, -- TEMP: capture the ACP handshake for debugging
				strategies = {
					chat = { adapter = "claude_code" }, -- default; switch live inside the chat with `ga`
					inline = { adapter = "ollama_inline" }, -- JSON-forced so parsing never fails
					cmd = { adapter = "ollama_inline" },
				},
				adapters = {
					http = {
						ollama = ollama_adapter(), -- prose (for chat-on-ollama)
						-- Inline requires a strict JSON reply. A plain `format="json"` guarantees valid
						-- JSON but not the right shape — weak models take the lazy path and return
						-- {"placement":"chat"}, which routes the reply to a chat instead of editing.
						-- Passing a full JSON schema (ollama structured outputs) forbids chat/new and
						-- requires `code`, so inline always produces an applicable buffer edit.
						ollama_inline = ollama_adapter({
							body = {
								format = {
									type = "object",
									properties = {
										placement = { type = "string", enum = { "replace", "add", "before" } },
										code = { type = "string" },
										language = { type = "string" },
									},
									required = { "placement", "code" },
								},
							},
						}),
					},
					acp = {
						claude_code = function()
							-- Auth via CLAUDE_CODE_OAUTH_TOKEN in the shell env (from `claude setup-token`).
							-- Bigger timeout: the bridge cold-starts a `claude` subprocess, and 20s can be
							-- too short on a loaded machine.
							return require("codecompanion.adapters").extend("claude_code", {
								defaults = { timeout = 90000 },
							})
						end,
						opencode = function()
							return require("codecompanion.adapters").extend("opencode", {})
						end,
					},
				},
			})
		end,
	},
}
