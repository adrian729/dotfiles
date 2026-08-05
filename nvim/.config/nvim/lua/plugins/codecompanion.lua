return {
	{
		"adrian729/ducktape.nvim",
		lazy = false, -- plugin/ducktape.lua owns keymaps + statusline; only runs at startup
		-- when this is a start plugin. codecompanion is deliberately not its
		-- dependency, so it stays deferred until the first ducktape action.
	},
	{
		"olimorris/codecompanion.nvim",
		event = "VeryLazy", -- KEEP THIS — the old `keys` table is gone, so nothing else makes
		-- this lazy; dropping event too makes lazy.nvim load it synchronously at startup.
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			extensions = {
				ducktape = { opts = {} },
			},
		},
	},
}
