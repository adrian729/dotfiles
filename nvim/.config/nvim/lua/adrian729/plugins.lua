---------------------------------------------------
-- Auto-install vim-plug and plugins on open vim --
---------------------------------------------------

local data_dir = vim.fn.stdpath('data')
if vim.fn.empty(vim.fn.glob(data_dir .. '/site/autoload/plug.vim')) == 1 then
  vim.cmd('silent !curl -fLo ' .. data_dir .. '/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim')
  vim.o.runtimepath = vim.o.runtimepath
  vim.cmd('autocmd VimEnter * PlugInstall --sync | source $MYVIMRC')
end


-----------------
-- Add plugins --
-----------------

local vim = vim
local Plug = vim.fn['plug#']

-- TODO: add script to autoinstall vim-plug https://github.com/junegunn/vim-plug?tab=readme-ov-file
vim.call('plug#begin')

Plug('catppuccin/nvim', { ['as'] = 'catppuccin' })

-- Post-update hook: run a shell command after installing or updating the plugin
Plug('junegunn/fzf', { ['dir'] = '~/.fzf', ['do'] = './install --all' })

Plug('nvim-lua/plenary.nvim')

Plug('nvim-telescope/telescope.nvim', { ['branch'] = '0.1.x' }) -- deps: nvim-lua/plenary.nvim

Plug('nvim-treesitter/nvim-treesitter', { ['do'] = ':TSUpdate' })
Plug('theprimeagen/harpoon', { ['branch'] = 'harpoon2' })
Plug('mbbill/undotree')
Plug('tpope/vim-fugitive')

-- LSP
Plug('neovim/nvim-lspconfig')
Plug('hrsh7th/nvim-cmp')
Plug('hrsh7th/cmp-nvim-lsp')
Plug('VonHeikemen/lsp-zero.nvim', { ['branch'] = 'v4.x' }) -- deps: neovim/nvim-lspconfig, hrsh7th/nvim-cmp, hrsh7th/cmp-nvim-lsp

vim.call('plug#end')

