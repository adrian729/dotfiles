-- explorer
vim.keymap.set("n", "<leader>ee", vim.cmd.Ex)

-- select
local select = require("nvim-treesitter-textobjects.select").select_textobject
vim.keymap.set({ "x", "o" }, "af", function()
    select("@function.outer", "textobjects")
end)
vim.keymap.set({ "x", "o" }, "if", function()
    select("@function.inner", "textobjects")
end)
vim.keymap.set({ "x", "o" }, "ac", function()
    select("@class.outer", "textobjects")
end)
vim.keymap.set({ "x", "o" }, "ic", function()
    select("@class.inner", "textobjects")
end)
vim.keymap.set({ "x", "o" }, "as", function()
    select("@local.scope", "locals")
end)
