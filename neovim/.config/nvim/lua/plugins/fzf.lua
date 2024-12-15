return {
  -- Post-update hook: run a shell command after installing or updating the plugin
  { 
    "junegunn/fzf",
    name = "fzf",
    dir = "~/.fzf",
    build = "./install --all"
  },
  { "junegunn/fzf.vim" },
}
