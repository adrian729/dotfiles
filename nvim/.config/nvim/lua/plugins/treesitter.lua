local parsers = {
	"lua",
	"rust",
	"rstml",
	"html",
	"markdown",
	"markdown_inline",
}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		dependencies = {
			{
				"rayliwell/tree-sitter-rstml",
				build = ":TSUpdate",
				config = function()
					require("tree-sitter-rstml").setup()
					-- Revert the filetype takeover so normal 'rust' is used
					-- Injections used to add rstml behaviour
					vim.treesitter.language.register("rust", { "rust" })
				end,
			},
		},
		config = function()
			-- Register rstml manually so it doesn't get skipped
			local function register_rstml()
				---@diagnostic disable: inject-field, missing-fields
				require("nvim-treesitter.parsers").rstml = {
					install_info = {
						url = "https://github.com/rayliwell/tree-sitter-rstml",
						branch = "main",
						files = { "src/parser.c", "src/scanner.c" },
						location = "rstml",
					},
				}
				---@diagnostic enable: inject-field, missing-fields
			end
			-- Must register before installing parsers
			register_rstml()
			-- attach to TSUpdate for nvim-treesitter reloading parsers table
			vim.api.nvim_create_autocmd("User", {
				pattern = "TSUpdate",
				callback = register_rstml,
			})

			local ts = require("nvim-treesitter")
			ts.install(parsers)

			local patterns = {}
			for _, parser in ipairs(parsers) do
				local ok, parser_patterns = pcall(vim.treesitter.language.get_filetypes, parser)
				if ok then
					for _, pp in pairs(parser_patterns) do
						table.insert(patterns, pp)
					end
				end
			end
			vim.api.nvim_create_autocmd("FileType", {
				pattern = patterns,
				callback = function()
					vim.treesitter.start()
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
	},
	{
		"MeanderingProgrammer/treesitter-modules.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		opts = {
			incremental_selection = {
				enable = true,
				disable = false,
				keymaps = {
					init_selection = "<leader>ss",
					node_incremental = "<leader>ss",
					scope_incremental = "<leader>sc",
					node_decremental = "<leader>sd",
				},
				indent = {
					enable = true,
					disable = false,
				},
			},
		},
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		keys = {
			{ "af", mode = { "x", "o" } },
			{ "if", mode = { "x", "o" } },
			{ "ac", mode = { "x", "o" } },
			{ "ic", mode = { "x", "o" } },
			{ "as", mode = { "x", "o" } },
		},
		init = function()
			-- Disable entire built-in ftplugin mappings to avoid conflicts.
			-- See https://github.com/neovim/neovim/tree/master/runtime/ftplugin for built-in ftplugins.
			vim.g.no_plugin_maps = true
		end,
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = {
					lookahead = true,
					selection_modes = {
						["@parameter.outer"] = "v",
						["@function.outer"] = "v",
						["@class.outer"] = "v",
					},
					include_surrounding_whitespace = false,
				},
			})
		end,
	},
}
