return {
	{
		"folke/lazydev.nvim", -- LuaLS config for nvim
		ft = "lua",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = true,
	},
	{
		"nvim-lua/plenary.nvim",
		lazy = false,
	},
}
