-- Set scroll offset
-- vim.opt.scrolloff = 999 does the same, but can cause problems in specific situations 
local vcenter_group = vim.api.nvim_create_augroup("VCenterCursor", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "WinNew", "VimResized" }, {
  group = vcenter_group,
  pattern = "*",
  callback = function()
    local win_height = vim.api.nvim_win_get_height(0)
    vim.opt.scrolloff = math.floor(win_height / 3)
  end,
})
