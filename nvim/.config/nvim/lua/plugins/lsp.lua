-- Prefer the Homebrew/Linuxbrew LLVM binary; fall back to PATH. Absolute path so
-- it resolves even when nvim is launched with a minimal (GUI) PATH.
local function llvm_bin(name)
	for _, dir in ipairs({
		"/opt/homebrew/opt/llvm/bin", -- macOS Homebrew
		"/home/linuxbrew/.linuxbrew/opt/llvm/bin", -- Linux Linuxbrew
	}) do
		local p = dir .. "/" .. name
		if vim.uv.fs_stat(p) then
			return p
		end
	end
	return name
end

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

			vim.lsp.config("rust_analyzer", {
				settings = {
					["rust-analyzer"] = {
						procMacro = {
							enable = true,
							ignored = {
								["async-trait"] = { "async_trait" },
								["napi-derive"] = { "napi" },
								["async-recursion"] = { "async_recursion" },
							},
						},
						cargo = {
							buildScripts = { enable = true },
							targetDir = true,
						},
						-- This helps with view! (leptos) macro diagnostics
						diagnostics = {
							disabled = { "unresolved-proc-macro" },
						},
						check = {
							command = "clippy",
						},
						numThreads = 4,
						cachePriming = { enable = false },
						files = {
							excludeDirs = { "target", "node_modules", ".direnv", ".venv" },
						},
					},
				},
			})

			vim.lsp.config("marksman", {
				settings = {
					marksman = {
						markdown = {
							gfm_heading_ids = true,
						},
					},
				},
			})

			local function clangd_cmd()
				return {
					llvm_bin("clangd"),
					"--background-index",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--completion-style=detailed",
					"--function-arg-placeholders=1",
					"--fallback-style=llvm",
				}
			end

			vim.lsp.config("clangd", {
				cmd = clangd_cmd(),
				init_options = {
					clangdFileStatus = true,
				},
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "markdown" },
				callback = function(args)
					vim.fn.jobstart({ "prettierd", "start" }, { detach = true })

					local opts = { buffer = args.buf, silent = true }

					vim.keymap.set("n", "gO", function()
						require("telescope.builtin").lsp_document_symbols({
							prompt_title = "Table of Contents",
							sorting_strategy = "ascending",
							layout_config = {
								vertical = {
									mirror = false,
									prompt_position = "top",
								},
							},
						})
					end, vim.tbl_extend("force", opts, { desc = "Document symbols (Telescope)" }))

					vim.opt_local.foldmethod = "expr"
					vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
					vim.opt_local.foldtext = ""
					vim.opt_local.foldlevel = 99

					vim.opt_local.conceallevel = 2
					vim.opt_local.concealcursor = ""
					pcall(vim.treesitter.start, args.buf)

					vim.opt_local.wrap = true
					vim.opt_local.linebreak = true
					vim.opt_local.breakindent = true

					vim.keymap.set("n", "]]", function()
						vim.fn.search("^#\\+\\s\\+", "W")
					end, vim.tbl_extend("force", opts, { desc = "Next Markdown Header" }))

					vim.keymap.set("n", "[[", function()
						vim.fn.search("^#\\+\\s\\+", "bW")
					end, vim.tbl_extend("force", opts, { desc = "Previous Markdown Header" }))
				end,
			})

			vim.lsp.enable({
				"lua_ls",
				"clangd",
				"rust_analyzer",
				"pyright",
				"marksman",
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
				rust = function(bufnr)
					local root = vim.fs.root(bufnr, { "Cargo.toml" })
					if root then
						local f = io.open(root .. "/Cargo.toml", "r")
						if f then
							for line in f:lines() do
								if line:match("^%s*leptos%s*[%.=]") then
									f:close()
									return { "leptosfmt" }
								end
							end
							f:close()
						end
					end
					return { "rustfmt" }
				end,
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
				markdown = { "prettierd", "prettier", stop_after_first = true },
				c = { "clang-format" },
				cpp = { "clang-format" },
			},
			formatters = {
				prettier = {
					args = { "--stdin-filepath", "$FILENAME", "--prose-wrap", "always", "--parser", "markdown" },
				},
				leptosfmt = {
					prepend_args = { "--rustfmt" },
				},
				["clang-format"] = {
					command = llvm_bin("clang-format"),
				},
			},
			format_on_save = function(bufnr)
				local slow_format_filetypes = {
					python = true,
					markdown = true,
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
