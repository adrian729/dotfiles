return {
	{
		"neovim/nvim-lspconfig",
		config = function()
			vim.lsp.config("lua_ls", {
				on_init = function(client)
					if client.workspace_folders then
						local path = client.workspace_folders[1].name
						if
							path ~= vim.fn.stdpath("config")
							and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc"))
						then
							return
						end
					end

					client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
						runtime = {
							version = "LuaJIT",
							path = {
								"lua/?.lua",
								"lua/?/init.lua",
							},
						},
						workspace = {
							checkThirdParty = false,
							library = {
								vim.env.VIMRUNTIME,
							},
						},
					})
				end,
				settings = {
					Lua = {},
				},
			})

			vim.lsp.enable({
				"lua_ls",
				"clangd",
				"rust_analyzer",
				"pyright",
			})
		end,
	},
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				python = function(bufnr)
					local function is_available(name)
						return require("conform").get_formatter_info(name, bufnr).available
					end

					if is_available("ruff_format") then
						return { "ruff_fix", "ruff_format" }
					elseif is_available("isort") and is_available("black") then
						return { "isort", "black" }
					end

					return { "black", "autopep8", stop_after_first = true }
				end,
			},
			format_on_save = function(bufnr)
				local slow_format_filetypes = {
					python = true,
				}

				local ft = vim.bo[bufnr].filetype
				local timeout = slow_format_filetypes[ft] and 2500 or 500

				return {
					timeout_ms = timeout,
					lsp_format = "fallback",
				}
			end,
		},
	},
}
