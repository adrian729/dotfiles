-- Shared presentation helpers: per-request progress virtual text, and the float that shows a
-- reply the buffer must not receive.

local api = vim.api

local M = {}

local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
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

---@param text string
---@param width number
---@return string
local function ellipsise(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	return vim.fn.strcharpart(text, 0, math.max(1, width - 1)) .. "…"
end

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

	local function clear()
		if mark and api.nvim_buf_is_valid(bufnr) then
			pcall(api.nvim_buf_del_extmark, bufnr, ns, mark)
		end
		mark = nil
	end

	local function render()
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
		if timer then
			timer:stop()
			if not timer:is_closing() then
				timer:close()
			end
			timer = nil
		end
		clear()
	end

	function handle.set_label(text)
		label = text
		render()
	end

	render()
	timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			frame = (frame % #SPINNER) + 1
			render()
		end)
	)

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

	local win = api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = (" %s — <CR> open in a chat · q dismiss "):format(opts.title),
		title_pos = "center",
	})
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

return M
