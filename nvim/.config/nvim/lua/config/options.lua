local opt = vim.opt

vim.g.have_nerd_fonts = true
opt.termguicolors = true
opt.number = true
opt.relativenumber = true
-- opt.colorcolumn = "80,132" -- done via autocmds to attach to ft
-- opt.scrolloff = 999 -- done via autocmds instead to avoid issues
opt.cursorline = true
opt.splitbelow = true
opt.splitright = true
opt.wrap = false
opt.updatetime = 250
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.clipboard = "unnamedplus" -- Sync system clipboard with nvim clipboard
opt.completeopt = { "menu", "menuone", "noselect" }
opt.virtualedit = "block"
opt.inccommand = "split"
opt.ignorecase = true
opt.smartcase = true
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.diagnostic.config({
	-- virtual_text = true,
	-- virtual_lines = false,
	virtual_lines = true,
})
