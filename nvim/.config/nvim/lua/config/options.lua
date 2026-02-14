-- UI
vim.g.have_nerd_fonts = true
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true
-- vim.opt.scrolloff = 999 -- done in "config.autocmds" instead to avoid issues
vim.opt.cursorline = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.wrap = false
-- Tab
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
-- Behaviour
vim.opt.clipboard = "unnamedplus" -- Sync system clipboard with nvim clipboard
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.virtualedit = "block"
vim.opt.inccommand = "split"
-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
-- Leader
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
-- Setup diagnostigs
vim.diagnostic.config({
    -- virtual_text = true,
    -- virtual_lines = false,
    virtual_lines = true,
})
