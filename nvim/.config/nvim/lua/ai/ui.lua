-- Shared presentation helpers: per-request progress virtual text, and the float that shows a
-- reply the buffer must not receive.

local api = vim.api

local M = {}

-- Shared with the inline list, so a request animates at the same tempo and in the same shape
-- wherever it is being watched from.
local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
M.SPINNER = SPINNER

local ns = api.nvim_create_namespace("ai_ui")

---Width available for virtual text on a row, so a long prompt gets an ellipsis instead of
---pushing the line off screen.
---@param bufnr number
---@param row number 0-indexed
---@return number
local function room_on(bufnr, row)
	local width = vim.o.columns
	for _, win in ipairs(api.nvim_list_wins()) do
		if api.nvim_win_get_buf(win) == bufnr then
			width = api.nvim_win_get_width(win)
			break
		end
	end
	local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	return math.max(20, width - vim.fn.strdisplaywidth(line) - 6)
end

---Truncate to a display width, marking that something was cut. By character rather than by
---byte, so a multibyte glyph is never sliced in half.
---@param text string
---@param width number
---@return string
function M.ellipsise(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	return vim.fn.strcharpart(text, 0, math.max(1, width - 1)) .. "…"
end

local ellipsise = M.ellipsise

---Animated virtual text pinned to a moving row.
---
---Virtual text rather than a cursor-relative float, because several requests can be in flight
---in one buffer and all of them have to be visible at once.
---@param bufnr number
---@param row_fn fun(): number|nil 0-indexed row, re-read every frame so the mark follows edits
---@param label string
---@return { stop: fun(), set_label: fun(text: string) }
function M.progress(bufnr, row_fn, label)
	local mark, frame = nil, 1
	local timer = vim.uv.new_timer()
	local handle = {}
	-- render() runs once before the timer starts, and its invalid-buffer branch calls stop(),
	-- which nils the timer out from under the start() below.
	local stopped = false

	local function clear()
		if mark and api.nvim_buf_is_valid(bufnr) then
			pcall(api.nvim_buf_del_extmark, bufnr, ns, mark)
		end
		mark = nil
	end

	local function render()
		if stopped then
			return clear()
		end
		if not api.nvim_buf_is_valid(bufnr) then
			return handle.stop()
		end
		local row = row_fn()
		if not row then
			return clear()
		end
		row = math.max(0, math.min(row, api.nvim_buf_line_count(bufnr) - 1))
		local text = (" %s %s "):format(SPINNER[frame], ellipsise(label, room_on(bufnr, row)))
		local ok, id = pcall(api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
			id = mark,
			virt_text = { { text, "DiagnosticVirtualTextHint" } },
			virt_text_pos = "eol",
			hl_mode = "combine",
		})
		if ok then
			mark = id
		end
	end

	function handle.stop()
		stopped = true
		clear()
		-- Defer timer teardown one tick so any mid-flight render() sees stopped and
		-- clears itself rather than racing with the extmark deletion above.
		vim.schedule(function()
			if timer then
				timer:stop()
				if not timer:is_closing() then
					timer:close()
				end
				timer = nil
			end
		end)
	end

	function handle.set_label(text)
		if stopped then
			return
		end
		label = text
		render()
	end

	render()
	if not stopped then
		timer:start(
			100,
			100,
			vim.schedule_wrap(function()
				frame = (frame % #SPINNER) + 1
				render()
			end)
		)
	end

	return handle
end

---A float showing a reply that must not be inserted — an answer, a refusal, or a failed tool
---attempt. Anchored at the target range so it is obvious which request it belongs to.
---@param opts { bufnr: number, row: number, title: string, text: string, on_confirm?: fun() }
---@return number winnr
function M.message(opts)
	local lines = {}
	for _, line in ipairs(vim.split(opts.text, "\n", { plain = true })) do
		vim.list_extend(lines, vim.split(line, "\r", { plain = true }))
	end

	local width = math.min(math.floor(vim.o.columns * 0.7), 90)
	local height = math.min(#lines + 1, math.floor(vim.o.lines * 0.5))

	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"

	local config = {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = (" %s — <CR> open in a chat · q dismiss "):format(opts.title),
		title_pos = "center",
	}

	-- Anchored at the target row when the buffer is on screen, so that with several requests in
	-- flight it is obvious which one is talking. Centred when it is not displayed anywhere.
	local host = opts.bufnr and vim.fn.bufwinid(opts.bufnr) or -1
	if host ~= -1 and opts.row then
		local rows = api.nvim_buf_line_count(opts.bufnr)
		config.relative = "win"
		config.win = host
		config.bufpos = { math.max(0, math.min(opts.row, rows - 1)), 0 }
		config.row, config.col = 1, 0
	end

	local win = api.nvim_open_win(buf, true, config)
	vim.wo[win].wrap = true

	local function close()
		if api.nvim_win_is_valid(win) then
			api.nvim_win_close(win, true)
		end
	end

	vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<esc>", close, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<cr>", function()
		close()
		if opts.on_confirm then
			opts.on_confirm()
		end
	end, { buffer = buf, nowait = true })

	return win
end

--=============================================================================
-- Highlighted list lines
--=============================================================================

---Assemble a display line from {text, highlight} segments. Telescope wants byte offsets,
---and the markers these lines carry are multibyte, so the offsets are accumulated from the
---segments rather than written out by hand — hand-written ones drift the moment a glyph
---changes, and a range landing mid-codepoint corrupts the whole line.
---@param segments { [1]: string, [2]: string|nil }[]
---@return string text, table highlights
function M.render(segments)
	local parts, highlights, offset = {}, {}, 0
	for _, seg in ipairs(segments) do
		local text = seg[1]
		if seg[2] and text ~= "" then
			table.insert(highlights, { { offset, offset + #text }, seg[2] })
		end
		table.insert(parts, text)
		offset = offset + #text
	end
	return table.concat(parts), highlights
end

---Pad to a display width — `#text` would over-pad anything holding a multibyte glyph.
---
---Only ever pads *to* the width. Callers wanting a gap after the column append it
---themselves: folding a minimum gap in here reads as "width plus the gap" but cannot be,
---since the two would have to be added rather than maxed, and a column narrower than the
---widest entry would silently lose its alignment instead of its gap.
---@param text string
---@param width number
---@return string
function M.pad(text, width)
	return text .. string.rep(" ", math.max(width - vim.fn.strdisplaywidth(text), 0))
end

--=============================================================================
-- Highlights — Catppuccin Mocha palette
--=============================================================================

-- Every ai surface draws from one palette, so the groups are defined once here rather than
-- per module: the winbar, the chat footer, the chat list and the provider picker had started
-- to keep their own copies of the same colours, which is how two of them drift apart.

local hl_ready = false

---Define every `Ai*` highlight group. Latches, so it is cheap to call from anywhere.
---
---Call it from a scheduled context at startup: the fallback branch below is permanent once
---this has run, so resolving the palette before catppuccin has loaded would leave the whole
---UI in stand-in colours for the rest of the session.
function M.ensure_highlights()
	if hl_ready then
		return
	end
	hl_ready = true

	local p = {}
	local ok, palette = pcall(function()
		return require("catppuccin.palettes").get_palette()
	end)
	if ok and palette then
		p = vim.tbl_extend("keep", { key = palette.blue }, palette)
	else
		-- Teal where it shows — a fallback that screams rather than looking plausible
		p = {
			mauve = "#94e2d5",
			pink = "#94e2d5",
			blue = "#c6a0f6", -- mauve
			key = "#94e2d5",
			green = "#a6e3a1",
			yellow = "#f9e2af",
			red = "#f38ba8",
			lavender = "#b4befe",
			overlay1 = "#7f849c",
			overlay0 = "#6c7086",
			subtext0 = "#a6adc8",
			surface1 = "#585b70",
			surface0 = "#45475a",
		}
	end

	local set = function(name, opts)
		vim.api.nvim_set_hl(0, name, opts)
	end

	-- Chat winbar
	set("AiWinBarProvider", { fg = p.mauve, bg = "NONE" })
	set("AiWinBarModel", { fg = p.pink, bg = "NONE" })
	set("AiWinBarTitle", { fg = p.blue, bg = "NONE" })
	set("AiWinBarDim", { fg = p.surface1, bg = "NONE" })
	set("AiWinBarSep", { fg = p.surface0, bg = "NONE" })

	-- Chat footer. It sits in the statusline, so it has to carry StatusLine's own background
	-- or it reads as a hole punched in the bar. A transparent theme leaves bg nil, which is
	-- then the right answer anyway.
	local sl = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
	local bg = sl and sl.bg or nil
	set("AiFooterKey", { fg = p.key, bg = bg, bold = true })
	set("AiFooterLabel", { fg = p.subtext0, bg = bg })
	set("AiFooterDim", { fg = p.overlay0, bg = bg })

	-- Chat list and the provider/model picker
	set("AiListReady", { fg = p.green, bg = "NONE" })
	set("AiListStarting", { fg = p.yellow, bg = "NONE" })
	set("AiListDead", { fg = p.red, bg = "NONE" })
	set("AiListCurrent", { fg = p.lavender, bg = "NONE", bold = true })
	set("AiListDim", { fg = p.overlay1, bg = "NONE" })
	set("AiListHeader", { fg = p.mauve, bg = "NONE", bold = true })
	set("AiListKey", { fg = p.blue, bg = "NONE", bold = true })
end

return M
