local map = vim.keymap.set
local select = require("nvim-treesitter-textobjects.select").select_textobject
local req_swap = require("nvim-treesitter-textobjects.swap")
local builtin = require("telescope.builtin")

-- ------------------------------------------------------------------
-- explorer
-- ------------------------------------------------------------------
map("n", "<leader>ee", vim.cmd.Ex, { desc = "Open file explorer" })
-- ------------------------------------------------------------------
-- select
-- ------------------------------------------------------------------
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
end, { desc = "Select class inner" })
map({ "x", "o" }, "as", function()
	select("@local.scope", "locals")
end, { desc = "Select local scope" })
-- ------------------------------------------------------------------
-- swap
-- ------------------------------------------------------------------
map("n", "<leader>a", function()
	req_swap.swap_next("@parameter.inner")
end, { desc = "Swap next arg" })
map("n", "<leader>A", function()
	req_swap.swap_previous("@parameter.inner")
end, { desc = "Swap prev arg" })
-- ------------------------------------------------------------------
-- local search
-- ------------------------------------------------------------------
map("n", "<leader>/", function()
	builtin.current_buffer_fuzzy_find({ previewer = true })
end, { desc = "Fuzzy search current buffer" })
-- ------------------------------------------------------------------
-- global search
-- ------------------------------------------------------------------
-- Pre-requisite with grep commands:
-- [ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation)
map("n", "<leader>sg", builtin.live_grep, { desc = "Live grep" })
map("n", "<leader>sw", builtin.grep_string, { desc = "Grep string" })
map("n", "<leader>ps", function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") })
end, { desc = "Project search" })
map("n", "<leader>sr", builtin.resume, { desc = "Resume last search" })
-- ------------------------------------------------------------------
-- navigation (files & buffers)
-- ------------------------------------------------------------------
map("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
map("n", "<leader>fo", builtin.oldfiles, { desc = "Find old files" })
map("n", "<leader>fb", ":Files<CR>", { desc = "Files (Binary/FZF)" })
map("n", "<leader>sb", builtin.buffers, { desc = "Find buffers" })
map("n", "]b", ":bnext<CR>", { desc = "Next Buffer" })
map("n", "[b", ":bprev<CR>", { desc = "Prev Buffer" })
map("n", "]q", ":cnext<CR>", { desc = "Next Quickfix" })
map("n", "[q", ":cprev<CR>", { desc = "Prev Quickfix" })
-- ------------------------------------------------------------------
-- LSP Actions
-- ------------------------------------------------------------------
map("n", "<leader>gd", builtin.lsp_definitions, { desc = "Go to LSP definitions" })
-- TODO: think if we want to just overwrite the default grr, gri, etc
map("n", "grr", function()
	builtin.lsp_references({ previewer = true })
end, { desc = "Go to LSP references" })
map("n", "gri", builtin.lsp_implementations, { desc = "Go to LSP implementations" })
-- gra - native
-- grx - native (codelens run)
map("n", "grn", function()
	return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true, desc = "Incremental Rename" })
map("n", "gO", builtin.lsp_document_symbols, { desc = "Document symbols (outline)" })
map("n", "gW", builtin.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols (global)" })
-- ------------------------------------------------------------------
-- diagnostics
-- ------------------------------------------------------------------
map("n", "<leader>fd", builtin.diagnostics, { desc = "Workspace diagnostics" })
map("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next Diagnostic" })
map("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Prev Diagnostic" })
map("n", "<leader>uh", function()
	local enabled = not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
	print("toggle inlay_hint: " .. tostring(enabled))
	vim.lsp.inlay_hint.enable(enabled, { bufnr = 0 })
end, { desc = "Toggle inlay hints (current buffer)" })
map("n", "<leader>uf", function()
	vim.g.lsp_folding = not vim.g.lsp_folding
	print("LSP folding: " .. tostring(vim.g.lsp_folding) .. " (fallback: treesitter)")
	vim.cmd("normal! zx")
end, { desc = "Toggle LSP folding (treesitter fallback)" })
-- ------------------------------------------------------------------
-- help
-- ------------------------------------------------------------------
map("n", "<leader>fh", builtin.help_tags, { desc = "Find help tags" })
map("n", "<leader>fk", builtin.keymaps, { desc = "Find keymaps" })

-- ------------------------------------------------------------------
-- git.lua keymaps
-- ------------------------------------------------------------------
-- <leader>gs - fugitive git status
-- <leader>glb - gitsigns current line blame
-- ------------------------------------------------------------------
-- treesitter.lua keymaps
-- ------------------------------------------------------------------
-- <leader>ss - init_select
-- <leader>ss - node_inc
-- <leader>sc - scope_inc
-- <leader>sd - node_dec
-- ------------------------------------------------------------------
-- lsp.lua markdown
-- ------------------------------------------------------------------
-- gO - overwrite - TOC
-- ]] - next header
-- [[ - prev header
-- ------------------------------------------------------------------
-- markdown.lua
-- ------------------------------------------------------------------
-- <leader>mp - toggle markdown preview (browser)
-- ------------------------------------------------------------------
-- codecompanion.lua
-- ------------------------------------------------------------------
-- <leader>cc - toggle chat (default/last)
-- <leader>cn - new chat: pick backend (+ model for ollama)
-- <leader>cq - close all chats
-- <leader>ca - action palette (n, x)
-- <leader>ci - inline prompt / refactor (n, x) — ollama, JSON-forced; spinner + blocks while busy
-- <leader>cx - unblock inline (reset busy) if a request hangs
-- <leader>cm - switch inline ollama model
-- <leader>ct - toggle ollama thinking (fast <-> higher quality)
-- <leader>cs - status popup: what each mode currently uses
-- ga         - (in chat buffer) switch that chat's backend + model
-- g2 / g3    - (after inline) accept / reject the proposed diff (g1 = always accept)
