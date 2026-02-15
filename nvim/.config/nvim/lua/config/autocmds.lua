-- Set scroll offset
local vcenter_group = vim.api.nvim_create_augroup("VCenterCursor", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "WinNew", "VimResized" }, {
	group = vcenter_group,
	pattern = "*",
	callback = function()
		local win_height = vim.api.nvim_win_get_height(0)
		vim.opt.scrolloff = math.floor(3 * win_height / 10)
	end,
})

-- FT rulers
local rulers = {
	lua = "80,120",
	rust = "80,100",
	python = "79,88",
	javascript = "80,120",
	typescript = "80,120",
	c = "80,100",
	cpp = "80,100",
}
vim.api.nvim_create_autocmd("FileType", {
	pattern = vim.tbl_keys(rulers),
	callback = function(ev)
		vim.opt_local.colorcolumn = rulers[ev.match]
	end,
})
