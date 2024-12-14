return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false, -- make sure this loads on startup (main colorscheme)
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
    },
    config = function()
      -- transp
      -- fix: opts transparent_background should be enough, but doesn't seem to work.
      -- comment out when the normal config works...
      -- Set nvim transparent background (to use the one from the terminal)
      local user_colors = vim.api.nvim_create_augroup("ColorSchemeGroup", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", { 
        pattern = "*",
        group = user_colors, 
        command = "highlight Normal ctermbg=NONE guibg=NONE",
      })
      -- psnart
      vim.cmd([[colorscheme catppuccin]])
    end,
  },
}
