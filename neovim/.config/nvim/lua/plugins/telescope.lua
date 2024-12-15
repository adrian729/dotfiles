return {
	{ "nvim-lua/plenary.nvim" }, {
	'nvim-telescope/telescope.nvim',
	tag = '0.1.8',
	dependencies = { 'nvim-lua/plenary.nvim' },
	keys = {
		{
			"<leader>ff",
			"<cmd>Telescope find_files<cr>",
			desc = "Telescope find files"
		},
		{
			"<leader>fg",
			"<cmd>Telescope git_files<cr>",
			desc = "Telescope git files"
		},
		-- Pre-requisite: install [ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation)
		{
			"<leader>ps",
			function()
				require("telescope.builtin").grep_string({
					search = vim.fn.input("Grep > ")
				});
			end,
			desc = "Telescope project search"
		}, {
		"<leader>fp",
		function()
			require("telescope.builtin").find_files({
				cwd = require("lazy.core.config").options.root
			})
		end,
		desc = "Find Plugin File"
	}
	}
}
}
