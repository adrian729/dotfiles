local map = vim.keymap.set

-- ------------------------------------------------------------------
-- explorer
-- ------------------------------------------------------------------
map("n", "<leader>ee", vim.cmd.Ex, { desc = "Open file explorer" })

-- ------------------------------------------------------------------
-- select - nvim-treesitter-textobjects
-- ------------------------------------------------------------------
local select = require("nvim-treesitter-textobjects.select").select_textobject
map({ "x", "o" }, "af", function()
	select("@function.outer", "textobjects")
end, { desc = "Select function outer" })
map({ "x", "o" }, "if", function()
	select("@function.inner", "textobjects")
end, { desc = "Select function inner" })
map({ "x", "o" }, "ac", function()
	select("@class.outer", "textobjects")
end, { desc = "Select class outer" })
map({ "x", "o" }, "ic", function()
	select("@class.inner", "textobjects")
end, { desc = "Select function inner" })
map({ "x", "o" }, "as", function()
	select("@local.scope", "locals")
end, { desc = "Select local scope" })

-- ------------------------------------------------------------------
-- telescope - nvim-telescope
-- ------------------------------------------------------------------
local builtin = require("telescope.builtin")
local dropdown = require("telescope.themes").get_dropdown
-- ------------------------------------------------------------------
-- local search
-- ------------------------------------------------------------------
map("n", "<leader>/", function()
	builtin.current_buffer_fuzzy_find(dropdown({ previewer = true }))
end, { desc = "Fuzzy search current buffer" })
-- ------------------------------------------------------------------
-- global search
-- ------------------------------------------------------------------
-- Pre-requisite with grep commands: install [ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation)
map("n", "<leader>sg", builtin.live_grep, { desc = "Live grep" })
map("n", "<leader>sw", builtin.grep_string, { desc = "Grep string" })
map("n", "<leader>ps", function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") })
end, { desc = "Project search" })
map("n", "<leader>sr", builtin.resume, { desc = "Resume last search" })
-- ------------------------------------------------------------------
-- navigation (files & buffers)
-- ------------------------------------------------------------------
map("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
map("n", "<leader>fo", builtin.oldfiles, { desc = "Telescope find old files" })
map("n", "<leader>fb", ":Files<CR>", { desc = "Files (Binary/FZF)" })
map("n", "<leader>sb", builtin.buffers, { desc = "Telescope buffers" })
map("n", "]b", ":bnext<CR>", { desc = "Next Buffer" })
map("n", "[b", ":bprev<CR>", { desc = "Prev Buffer" })
map("n", "]q", ":cnext<CR>", { desc = "Next Quickfix" })
map("n", "[q", ":cprev<CR>", { desc = "Prev Quickfix" })
-- ------------------------------------------------------------------
-- LSP Actions
-- ------------------------------------------------------------------
map("n", "<leader>gd", builtin.lsp_definitions, { desc = "Telescope LSP definitions" })
-- TODO: think if we want to just overwrite the default grr, gri, etc
map("n", "grr", function()
	builtin.lsp_references(dropdown({ previewer = true }))
end, { desc = "Telescope LSP references" })
map("n", "gri", builtin.lsp_implementations, { desc = "Telescope LSP implementations" })
-- gra - native
map("n", "grn", function()
	return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true, desc = "Incremental Rename" })
map("n", "<leader>ss", builtin.lsp_document_symbols, { desc = "Telescope LSP doc symbols" })
map("n", "<leader>sS", builtin.lsp_dynamic_workspace_symbols, { desc = "Telescope LSP workspace symbols" })
-- ------------------------------------------------------------------
-- diagnostics
-- ------------------------------------------------------------------
map("n", "<leader>fd", builtin.diagnostics, { desc = "Workspace diagnostics" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev Diagnostic" })
-- ------------------------------------------------------------------
-- help
-- ------------------------------------------------------------------
map("n", "<leader>fh", builtin.help_tags, { desc = "Find help tags" })
map("n", "<leader>fk", builtin.keymaps, { desc = "Find keymaps" })
