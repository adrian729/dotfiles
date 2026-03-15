return {
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		ft = { "markdown" },
		build = "cd app && npm install",
		init = function()
			vim.g.mkdp_filetypes = { "markdown" }
			vim.g.mkdp_auto_close = 0
		end,
		keys = {
			{
				"<leader>mp",
				"<cmd>MarkdownPreviewToggle<cr>",
				desc = "Toggle Markdown Preview (browser)",
				ft = "markdown",
			},
		},
	},
}
