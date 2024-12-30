-- define common options
local opts = {
  noremap = true, -- non-recursive
  silent = true,  -- do not show message
}
local map = vim.keymap.set

-----------------
--  Settings   --
-----------------

vim.g.mapleader = " "

-----------------
-- Normal mode --
-----------------

map("n", "<leader>cll",
  function()
    local lazy = require 'lazy'
    local l_opts = { wait = false, show = false }
    lazy.update(l_opts)
    lazy.sync(l_opts)
    print 'Lazy update and sync done!'
  end,
  { desc = "Lazy Update and Sync" }
)
map("n", "<leader>clu",
  function()
    local lazy = require 'lazy'
    local l_opts = { wait = false, show = false }
    lazy.update(l_opts)
    print 'Lazy update done!'
  end,
  { desc = "Lazy Update" }
)

map("n", "<leader>cls",
  function()
    local lazy = require 'lazy'
    local l_opts = { wait = false, show = false }
    lazy.sync(l_opts)
    print 'Lazy sync done!'
  end,
  { desc = "Lazy Sync" }
)

-- Explorer
map("n", "<leader>ee", vim.cmd.Ex, { desc = "Open file explorer" })
map("n", "<leader>es", "<cmd>Sex!<CR>", { desc = "Open file explorer - split" })
map("n", "<leader>ed", vim.cmd.Sex, { desc = "Open file explorer - divide" })

-- tmux sessionizer
map("n", "<leader>ts", "<cmd>!tmux neww tmux-sessionizer<CR>", { silent = true })

-- chmod
map("n", "<leader>cx", "<cmd>!chmod +x %<CR>", { silent = true })

-- Hint: see `:h vim.map.set()`
-- Better window navigation
--map('n', '<C-h>', '<C-w>h', opts)
--map('n', '<C-j>', '<C-w>j', opts)
--map('n', '<C-k>', '<C-w>k', opts)
--map('n', '<C-l>', '<C-w>l', opts)

-- Resize with arrows
-- delta: 2 lines
map('n', '<C-Up>', ':resize -2<CR>', opts)
map('n', '<C-Down>', ':resize +2<CR>', opts)
map('n', '<C-Left>', ':vertical resize -2<CR>', opts)
map('n', '<C-Right>', ':vertical resize +2<CR>', opts)

-----------------
-- Visual mode --
-----------------

-- Hint: start visual mode with the same area as the previous area and the same mode
map('v', '<', '<gv', opts)
map('v', '>', '>gv', opts)
