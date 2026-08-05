# Moved to ducktape.nvim

This AI layer no longer lives in these dotfiles. It's now the standalone plugin
[`ducktape.nvim`](https://github.com/adrian729/ducktape.nvim), consumed from
`nvim/.config/nvim/lua/plugins/codecompanion.lua` via lazy.nvim's `dev` override
(`~/projects/ducktape.nvim` locally, a normal GitHub clone elsewhere).

See the plugin's own `docs/keymaps.md` for the current keymap list.
