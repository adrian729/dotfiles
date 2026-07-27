-- Minimal init for the plenary specs: the config's own lua/ directory plus plenary, and
-- nothing else. Keeps the specs independent of plugin load order and of lazy.nvim.
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(here)

local plenary = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary) == 0 then
	error("plenary.nvim not found at " .. plenary .. " — it ships as a codecompanion.nvim dependency")
end
vim.opt.runtimepath:prepend(plenary)

vim.opt.swapfile = false
