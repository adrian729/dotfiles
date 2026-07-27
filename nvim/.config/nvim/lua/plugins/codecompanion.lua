return {
	{
		"olimorris/codecompanion.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
		config = function()
			require("codecompanion").setup({})
		end,
	},
}
