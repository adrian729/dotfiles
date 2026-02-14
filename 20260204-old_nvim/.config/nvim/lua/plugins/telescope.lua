return {
  { "nvim-lua/plenary.nvim" },
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      {
        "<leader>fl",
        "<cmd>Telescope<cr>",
        desc = "Telescope options list"
      },
      {
        "<leader>ft",
        "<cmd>Telescope treesitter<cr>",
        desc = "Telescope treesitter"
      },
      {
        "<leader>rf",
        "<cmd>Telescope resume<cr>",
        desc = "Telescope resume"
      },
      {
        "<leader>ff",
        "<cmd>Telescope find_files<cr>",
        desc = "Telescope find files"
      },
      {
        "<leader>fg",
        "<cmd>Telescope git_files<cr>",

        { "nvim-lua/plenary.nvim" },
        desc = "Telescope git files"
      },
      -- Pre-requisite: install [ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation)
      {
        "<leader>ps",
        function()
          require("telescope.builtin").grep_string({
            search = vim.fn.input("Grep > ")
          });
        end,
        desc = "Telescope project search"
      },
      {
        "<leader>fs",
        "<cmd>Telescope current_buffer_fuzzy_find<cr>",
        desc = "Telescope current buffer fzf"
      },
      {
        "<leader>fp",
        function()
          require("telescope.builtin").find_files({
            cwd = require("lazy.core.config").options.root
          })
        end,
        desc = "Find Plugin File"
      },
      {
        "<leader>fk",
        "<cmd>Telescope keymaps<cr>",
        desc = "Telescope normal keymaps"
      },
      {
        "<leader>fhl",
        "<cmd>Telescope highlights<cr>",
        desc = "List available highlights"
      },
    }
  }
}
