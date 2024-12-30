return {
  {
    "folke/lazy.nvim",
    version = false,
  },
  { "nvim-lua/plenary.nvim" },
  { 'nvim-tree/nvim-web-devicons' },
  {
    'echasnovski/mini.icons',
    version = '*'
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
  },
}
