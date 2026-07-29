-- Adapter definitions live here rather than with the chat module because the connection pool
-- spawns connections *from* adapters — putting them later would make inline depend on a step
-- that comes after it. Everything they read about the current selection comes from ai.providers.

---Factory for an ollama HTTP adapter. `overrides` is deep-merged over the shared schema.
local function ollama_adapter(overrides)
	return function()
		local providers = require("ai.providers")
		return require("codecompanion.adapters").extend(
			"ollama",
			vim.tbl_deep_extend("force", {
				schema = {
					model = {
						default = function()
							return providers.current("inline").opts.model
						end,
					},
					think = {
						default = function()
							return providers.current("inline").opts.think == "on"
						end,
					},
					keep_alive = { default = "30m" }, -- keeps the local model warm between calls
					num_ctx = { default = 16384 }, -- ollama's own default silently truncates a real refactor
				},
			}, overrides or {})
		)
	end
end

return {
	{
		"olimorris/codecompanion.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = {
			"CodeCompanion",
			"CodeCompanionChat",
			"CodeCompanionActions",
			-- Registered here, not only in config(): a command defined inside config() cannot
			-- load the plugin that defines it, and at this point nothing else would.
			"AiPoolStatus",
			"AiDebugSend",
		},
		keys = {
			{
				"<leader>cc",
				function()
					require("ai.chat").toggle()
				end,
				desc = "AI: toggle last chat",
			},
			{
				"<leader>ca",
				"<cmd>CodeCompanionActions<cr>",
				mode = { "n", "x" },
				desc = "CodeCompanion: action palette",
			},
			{
				"<leader>ci",
				function()
					require("ai.inline").run(false)
				end,
				mode = { "n", "x" },
				desc = "AI: inline prompt (no tools)",
			},
			{
				"<leader>cI",
				function()
					require("ai.inline").run(true)
				end,
				mode = { "n", "x" },
				desc = "AI: inline prompt, may read the repo",
			},
			{
				"<leader>cmi",
				function()
					require("ai.inline").pick()
				end,
				desc = "AI: switch inline backend / model",
			},
			{
				"<leader>cmc",
				function()
					require("ai.chat").pick()
				end,
				desc = "AI: switch chat backend / model",
			},
			{
				"<leader>cn",
				function()
					require("ai.chat").new()
				end,
				mode = { "n", "x" },
				desc = "AI: new chat (current provider + options)",
			},
			{
				"<leader>cq",
				function()
					require("ai.chat").close_all()
				end,
				desc = "AI: close all chats",
			},
			{
				"<leader>cQ",
				function()
					require("ai.chat").stop()
				end,
				desc = "AI: stop the running chat request",
			},
			{
				"<leader>cs",
				function()
					require("ai.status").toggle()
				end,
				desc = "AI: status panel",
			},
			{
				"<leader>cl",
				function()
					require("ai.chat_list").open()
				end,
				desc = "AI: chat list",
			},
			{
				"<leader>cx",
				function()
					require("ai.inline").cancel()
				end,
				desc = "AI: cancel inline request(s)",
			},
		},
		config = function()
			local providers = require("ai.providers")

			require("codecompanion").setup({
				interactions = {
					chat = { adapter = "claude_code" },
					-- The built-in inline is superseded by ai/inline, but :CodeCompanion and
					-- :CodeCompanionCmd survive and would otherwise inherit the plugin's own
					-- default, which this machine has no credentials for.
					inline = { adapter = "ollama_cloud" },
					cmd = { adapter = "ollama_cloud" },
				},
				adapters = {
					http = {
						ollama = ollama_adapter({ env = { url = "http://localhost:11434" } }),
						ollama_cloud = ollama_adapter({
							env = {
								url = "https://ollama.com",
								api_key = function()
									return os.getenv("OLLAMA_API_KEY")
								end,
							},
							headers = { Authorization = "Bearer ${api_key}" },
						}),
					},
					acp = {
						claude_code = function()
							local adapter = require("codecompanion.adapters").extend("claude_code", {
								-- The stock value is 20s, and every adapter definition must restate
								-- the 90s one or silently inherit it.
								defaults = {
									timeout = 90000,
									-- The actual write defence: dontAsk denies mutating tools,
									-- shell redirects included. Chat overrides this per session.
									session_config_options = { mode = "dontAsk" },
								},
								-- Hygiene, not enforcement — the capability is inert for both
								-- agents. Advertise nothing we do not intend to serve.
								parameters = {
									clientCapabilities = { fs = { readTextFile = false, writeTextFile = false } },
								},
							})
							-- Drops CLAUDE_CODE_OAUTH_TOKEN from the adapter definition, which is
							-- unnecessary since authMethods is empty. Hygiene only, on two counts:
							-- the child process still inherits the variable from nvim's own
							-- environment, and the old _establish_session stalls turned out to be a
							-- stale claude-agent-acp 0.55.0 that nvm's bin directory put ahead of
							-- Homebrew's 0.59.0 on PATH — not this token (findings.md).
							-- Assigned rather than merged: tbl_deep_extend cannot remove a key.
							adapter.env = {}
							-- `--yolo` is the exact opposite of what inline wants
							adapter.commands.yolo = nil
							return adapter
						end,
						opencode = function()
							local adapter = require("codecompanion.adapters").extend("opencode", {
								defaults = { timeout = 90000 },
								parameters = {
									clientCapabilities = { fs = { readTextFile = false, writeTextFile = false } },
								},
							})
							adapter.env = {
								OPENCODE_PERMISSION = function()
									return vim.json.encode(providers.opencode_permission)
								end,
							}
							return adapter
						end,
					},
				},
			})

			require("ai.debug").setup()
		end,
	},
}
