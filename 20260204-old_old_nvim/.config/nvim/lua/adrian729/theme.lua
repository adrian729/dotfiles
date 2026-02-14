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

-- Set nvim transparent background (to use the one from the terminal)
local user_colors = vim.api.nvim_create_augroup("ColorSchemeGroup", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { 
    pattern = "*",
    group = user_colors, 
    command = "highlight Normal ctermbg=NONE guibg=NONE",
})

-- We prepend it with 'silent!' to ignore errors when it's not yet installed.
vim.cmd('silent! colorscheme catppuccin-mocha') -- catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha

