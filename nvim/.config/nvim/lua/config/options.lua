local opt = vim.opt

-- Hint: use `:h <option>` to figure out the meaning if needed
opt.clipboard = 'unnamedplus' -- use system clipboard
opt.completeopt = { 'menu', 'menuone', 'noselect' }
-- opt.mouse = 'a'               -- allow the mouse to be used in Nvim

-- Tab
opt.tabstop = 2      -- number of visual spaces per TAB
opt.softtabstop = 2  -- number of spacesin tab when editing
opt.shiftwidth = 2   -- insert 4 spaces on a tab
opt.expandtab = true -- tabs are spaces, mainly because of python

-- UI config
opt.number = true         -- show absolute number
opt.relativenumber = true -- add numbers to each line on the left side
opt.cursorline = true     -- highlight cursor line underneath the cursor horizontally
opt.splitbelow = true     -- open new vertical split bottom
opt.splitright = true     -- open new horizontal splits right
opt.termguicolors = true  -- enable 24-bit RGB color in the TUI
-- opt.showmode = false            -- we are experienced, wo don't need the "-- INSERT --" mode hint
opt.scrolloff = 12        -- set scroll padding

-- Searching
opt.incsearch = true  -- search as characters are entered
-- opt.hlsearch = false            -- do not highlight matches
opt.ignorecase = true -- ignore case in searches by default
opt.smartcase = true  -- but make it case sensitive if an uppercase is entered

-- nerd fonts
vim.g.have_nerd_font = true
