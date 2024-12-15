-- define common options
local opts = {
  noremap = true,   -- non-recursive
  silent = true,    -- do not show message
}
local map = vim.keymap.set

-----------------
--  Settings   --
-----------------

vim.g.mapleader = " "
map("n", "<leader>pv", vim.cmd.Ex, { desc = "Open file explorer" })

-----------------
-- Normal mode --
-----------------

-- Hint: see `:h vim.map.set()`
-- Better window navigation
--map('n', '<C-h>', '<C-w>h', opts)
--map('n', '<C-j>', '<C-w>j', opts)
--map('n', '<C-k>', '<C-w>k', opts)
--map('n', '<C-l>', '<C-w>l', opts)

-- Resize with arrows
-- delta: 2 lines
--map('n', '<C-Up>', ':resize -2<CR>', opts)
--map('n', '<C-Down>', ':resize +2<CR>', opts)
--map('n', '<C-Left>', ':vertical resize -2<CR>', opts)
--map('n', '<C-Right>', ':vertical resize +2<CR>', opts)

-----------------
-- Visual mode --
-----------------

-- Hint: start visual mode with the same area as the previous area and the same mode
-- map('v', '<', '<gv', opts)
-- map('v', '>', '>gv', opts)
