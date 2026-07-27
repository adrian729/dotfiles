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
			-- setup()'s own attach autocmds miss the buffer that triggered the lazy-load;
			-- deferred because BufReadPre fires before the file's content is read, so an
			-- immediate attach would highlight an empty buffer
			vim.schedule(function()
				require("colorizer").attach_to_buffer(0)
			end)
		end,
	},
}
