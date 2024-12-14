return {
  -- Post-update hook: run a shell command after installing or updating the plugin
  -- Plug('junegunn/fzf', { ['dir'] = '~/.fzf', ['do'] = './install --all' })
  { 
    "junegunn/fzf",
    name = "fzf",
    dir = "~/.fzf",
    build = "./install --all"
  },
  { "junegunn/fzf.vim" },
  { "nvim-lua/plenary.nvim" },
}
