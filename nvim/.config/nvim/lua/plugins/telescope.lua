return {
	{
		"nvim-telescope/telescope.nvim",
		lazy = false,
		version = "*",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		},
		opts = {
			defaults = {
				layout_strategy = "vertical",
				layout_config = {
					vertical = {
						width = 0.9,
						height = 0.95,
						preview_height = 0.2,
						mirror = true,
					},
				},
			},
		},
	},
}
