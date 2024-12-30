local M = {
	"nvim-treesitter/nvim-treesitter",
	version = false, -- last release is way too old and doesn't work on Windows
	build = function()
		require("nvim-treesitter.install").update({ with_sync = true })()
	end,
	event = { "VeryLazy" },
	lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
	init = function(plugin)
		-- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
		-- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
		-- no longer trigger the **nvim-treesitter** module to be loaded in time.
		-- Luckily, the only things that those plugins need are the custom queries, which we make available
		-- during startup.
		require("lazy.core.loader").add_to_rtp(plugin)
		require("nvim-treesitter.query_predicates")
	end,
	cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
	keys = {
		{ "<c-space>", desc = "Increment Selection" },
		{ "<bs>",      desc = "Decrement Selection", mode = "x" },
	},
	opts_extend = { "ensure_installed" },
	---@type TSConfig
	---@diagnostic disable-next-line: missing-fields
	opts = {
		vim.lsp.protocol.make_client_capabilities(),
		-- A list of parser names, or "all" (the listed parsers MUST always be installed)
		ensure_installed = {
			"javascript",
			"typescript",
			"c",
			"lua",
			"vim",
			"vimdoc",
			"query",
			"markdown",
			"markdown_inline"
		},
		-- Install parsers synchronously (only applied to `ensure_installed`)
		sync_install = false,
		-- Automatically install missing parsers when entering buffer
		-- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
		auto_install = true,
		-- List of parsers to ignore installing (or "all")
		ignore_install = {},
		highlight = {
			enable = true,
			-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
			-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
			-- Using this option may slow down your editor, and you may see some duplicate highlights.
			-- Instead of true it can also be a list of languages
			additional_vim_regex_highlighting = false,
		},
		indent = { enable = true },
	},
	---@param opts TSConfig
	config = function(_, opts)
		require("nvim-treesitter.configs").setup(opts)
	end,
}

return { M }
