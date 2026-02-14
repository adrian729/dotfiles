vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.wrap = false

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4

-- Sync system clipboard with nvim clipboard
vim.opt.clipboard = "unnamedplus"

-- vim.opt.scrolloff = 999 -- done in "config.autocmds" instead to avoid issues

vim.opt.virtualedit = "block"

vim.opt.inccommand = "split"

vim.opt.ignorecase = true

vim.opt.termguicolors = true

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup diagnostigs
vim.diagnostic.config({
    -- virtual_text = true,
    -- virtual_lines = false,
    virtual_lines = true,
})
