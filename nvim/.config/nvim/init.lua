require("config")

local vim = vim
local Plug = vim.fn['plug#']

-- TODO: add script to autoinstall vim-plug https://github.com/junegunn/vim-plug?tab=readme-ov-file
vim.call('plug#begin')

-- Post-update hook: run a shell command after installing or updating the plugin
Plug('junegunn/fzf', { ['dir'] = '~/.fzf', ['do'] = './install --all' })

Plug('nvim-lua/plenary.nvim')
Plug('nvim-telescope/telescope.nvim', { ['tag'] = '0.1.8' })

vim.call('plug#end')

-- Color schemes should be loaded after plug#end().
-- We prepend it with 'silent!' to ignore errors when it's not yet installed.
vim.cmd('silent! colorscheme seoul256')

