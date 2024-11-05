-- Color schemes should be loaded after plug#end() (plugins.lua).

-- Overwritte colors here
require("catppuccin").setup {
    color_overrides = {
        all = {
        },
        mocha = {
        }
    }
}

-- We prepend it with 'silent!' to ignore errors when it's not yet installed.
vim.cmd('silent! colorscheme catppuccin-mocha') -- catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha

