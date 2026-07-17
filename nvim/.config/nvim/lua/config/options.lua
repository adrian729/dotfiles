local opt = vim.opt

-- nvm lazy-loads `node`/`npm`/`npx`/`nvm` as shell functions (see zsh/.zshrc), so a fresh
-- shell's PATH never gets the node bin dir unless one of those is invoked first. Plugins
-- that spawn npm-installed binaries directly (e.g. codecompanion.nvim's claude-agent-acp)
-- inherit nvim's PATH as-is and fail with ENOENT. Prepend the highest installed node
-- version's bin dir here so those spawns work regardless of how nvim was launched.
local function ensure_nvm_path()
	local versions_dir = vim.fn.expand("$HOME/.nvm/versions/node")
	if vim.fn.isdirectory(versions_dir) == 0 then
		return
	end
	local versions = vim.fn.glob(versions_dir .. "/*", false, true)
	table.sort(versions, function(a, b)
		local function parts(v)
			return vim.tbl_map(tonumber, vim.split(v:match("v([%d.]+)$") or "0", "."))
		end
		local pa, pb = parts(a), parts(b)
		for i = 1, math.max(#pa, #pb) do
			local na, nb = pa[i] or 0, pb[i] or 0
			if na ~= nb then
				return na < nb
			end
		end
		return false
	end)
	local latest = versions[#versions]
	if not latest then
		return
	end
	local bin = latest .. "/bin"
	if not vim.tbl_contains(vim.split(vim.env.PATH or "", ":"), bin) then
		vim.env.PATH = bin .. ":" .. (vim.env.PATH or "")
	end
end
ensure_nvm_path()

vim.g.have_nerd_fonts = true
opt.termguicolors = true
opt.number = true
opt.relativenumber = true
-- opt.colorcolumn = "80,132" -- done via autocmds to attach to ft
-- opt.scrolloff = 999 -- done via autocmds instead to avoid issues
opt.cursorline = true
opt.splitbelow = true
opt.splitright = true
opt.wrap = false
opt.updatetime = 250
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.clipboard = "unnamedplus" -- Sync system clipboard with nvim clipboard
opt.completeopt = { "menu", "menuone", "noselect" }
opt.virtualedit = "block"
opt.inccommand = "split"
opt.ignorecase = true
opt.smartcase = true
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.diagnostic.config({
	-- virtual_text = true,
	-- virtual_lines = false,
	virtual_lines = true,
})

vim.g.lsp_folding = true

function _G.smart_foldexpr()
	if vim.g.lsp_folding then
		local buf = vim.api.nvim_get_current_buf()
		if next(vim.lsp.get_clients({ bufnr = buf, method = "textDocument/foldingRange" })) then
			return vim.lsp.foldexpr()
		end
	end
	return vim.treesitter.foldexpr()
end

opt.foldmethod = "expr"
opt.foldexpr = "v:lua.smart_foldexpr()"
opt.foldtext = ""
opt.foldlevel = 99
opt.foldlevelstart = 99
