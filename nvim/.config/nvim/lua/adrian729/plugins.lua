local vim = vim
local Plug = vim.fn['plug#']

-- TODO: add script to autoinstall vim-plug https://github.com/junegunn/vim-plug?tab=readme-ov-file
vim.call('plug#begin')

Plug('catppuccin/nvim', { ['as'] = 'catppuccin' })

-- Post-update hook: run a shell command after installing or updating the plugin
Plug('junegunn/fzf', { ['dir'] = '~/.fzf', ['do'] = './install --all' })

Plug('nvim-lua/plenary.nvim')

Plug('nvim-telescope/telescope.nvim', { ['branch'] = '0.1.x' })

Plug('nvim-treesitter/nvim-treesitter', { ['do'] = ':TSUpdate'})
Plug('theprimeagen/harpoon', { ['branch'] = 'harpoon2' })
Plug('mbbill/undotree')
Plug('tpope/vim-fugitive')

vim.call('plug#end')

