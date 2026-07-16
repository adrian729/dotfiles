return {
	{
		"catgoose/nvim-colorizer.lua",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("colorizer").setup({
				options = {
					parsers = { css = true },
				},
			})
			-- setup()'s own attach autocmds miss the buffer that triggered the lazy-load
			require("colorizer").attach_to_buffer(0)
		end,
	},
}
