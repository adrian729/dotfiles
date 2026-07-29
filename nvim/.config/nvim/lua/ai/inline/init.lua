-- Inline editing: prompt, placement, anchoring, diff, accept/reject, concurrency, cancellation.
--
-- The contract is that nvim decides placement and the model only supplies code. A visual
-- selection is replaced exactly; with no selection the reply is inserted at the cursor. The
-- model never says where its output goes, so it cannot route an edit into a chat, a new buffer,
-- or anywhere outside the range the user picked.

local api = vim.api

local input = require("codecompanion.interactions.shared.input")
local parse = require("ai.inline.parse")
local providers = require("ai.providers")
local ui = require("ai.ui")

local M = {}

-- Anchors and reject-time region marks. Separate from ai.ui's namespace so clearing progress
-- text can never disturb an anchor.
local ANCHOR = api.nvim_create_namespace("ai_inline_anchor")
local CONTEXT_LINES = 40
local seq = 0

---@type table<number, { requests: table<number, table>, diffs: table<number, table>, augroup?: number }>
local buffers = {}

local function buf_state(bufnr)
	buffers[bufnr] = buffers[bufnr] or { requests = {}, diffs = {} }
	return buffers[bufnr]
end

local function count(tbl)
	local n = 0
	for _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

--=============================================================================
-- Range capture and anchoring
--=============================================================================

---@return { s0: number, e0: number, has_selection: boolean }
local function capture_range()
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		-- Leave visual first so the '< and '> marks are set
		vim.cmd("normal! \27")
		return { s0 = vim.fn.line("'<") - 1, e0 = vim.fn.line("'>"), has_selection = true }
	end
	local row = api.nvim_win_get_cursor(0)[1] - 1
	-- An empty range at the cursor line: the reply is inserted, nothing is replaced
	return { s0 = row, e0 = row, has_selection = false }
end

---A row that nvim_buf_set_extmark will accept, the column to use on it, and whether the row had
---to be moved to get there.
---
---An exclusive end row equal to the line count has no line to sit on, so it becomes the end of
---the last line instead. `resolve` needs to tell that apart from a mark that genuinely sits at
---the start of the last line, or a selection running to the end of the buffer silently loses its
---final line and the reply's own last line is appended as a duplicate.
---
---The third return value is what carries that, rather than the column: reading the column back
---cannot distinguish the two cases when the last line is **empty**, because then the end of the
---line and the start of it are the same position. A buffer ending in a blank line is ordinary,
---and so is a buffer that is nothing but one.
---@param bufnr number
---@param row number
---@return number row, number col, boolean clamped
local function clamp(bufnr, row)
	local total = api.nvim_buf_line_count(bufnr)
	if row < total then
		return row, 0, false
	end
	local last = math.max(0, total - 1)
	return last, #(api.nvim_buf_get_lines(bufnr, last, last + 1, false)[1] or ""), true
end

---Anchor a range with extmarks so edits elsewhere — including another inline accept — shift it
---correctly. The built-in snapshots whole-buffer line numbers instead, which is exactly why two
---of its requests corrupt each other.
---@param bufnr number
---@param range table
---@return table anchor
local function anchor(bufnr, range)
	local srow, scol = clamp(bufnr, range.s0)
	local erow, ecol, ends_at_eof = clamp(bufnr, range.e0)

	local marks = {
		ends_at_eof = ends_at_eof,
		start = api.nvim_buf_set_extmark(bufnr, ANCHOR, srow, scol, { right_gravity = false }),
		finish = api.nvim_buf_set_extmark(bufnr, ANCHOR, erow, ecol, { right_gravity = true }),
	}

	-- A separate mark whose only job is to disappear if the whole range is deleted. Collapsing
	-- start onto finish is not a reliable test on its own: a user who deletes the range and
	-- types a replacement leaves the pair spanning unrelated text.
	if range.e0 > range.s0 then
		marks.guard = api.nvim_buf_set_extmark(bufnr, ANCHOR, srow, scol, {
			end_row = erow,
			end_col = ecol,
			invalidate = true,
			undo_restore = false,
		})
	end

	return marks
end

---@param bufnr number
---@param marks table
---@return number|nil s0, number|nil e0
local function resolve(bufnr, marks)
	if not api.nvim_buf_is_valid(bufnr) then
		return nil
	end
	if marks.guard then
		local g = api.nvim_buf_get_extmark_by_id(bufnr, ANCHOR, marks.guard, {})
		if not g or #g == 0 then
			return nil
		end
	end
	local s = api.nvim_buf_get_extmark_by_id(bufnr, ANCHOR, marks.start, {})
	local e = api.nvim_buf_get_extmark_by_id(bufnr, ANCHOR, marks.finish, {})
	if not s or #s == 0 or not e or #e == 0 then
		return nil
	end
	-- The mark could not be placed on its own row, so it sits on the last line and that line is
	-- part of the region: line-wise, the exclusive end is the row after it.
	local e0 = marks.ends_at_eof and (e[1] + 1) or e[1]
	return s[1], math.max(s[1], e0)
end

local function drop_marks(bufnr, marks)
	if not (marks and api.nvim_buf_is_valid(bufnr)) then
		return
	end
	for _, id in pairs(marks) do
		-- marks carries the ends_at_eof flag alongside the ids
		if type(id) == "number" then
			pcall(api.nvim_buf_del_extmark, bufnr, ANCHOR, id)
		end
	end
end

--=============================================================================
-- Prompt
--=============================================================================

-- One contract for every transport. An earlier revision asked HTTP and relay for a
-- `{"code":"…"}` envelope instead; that is reverted, and deliberately not to be reintroduced.
-- Measured on ollama cloud with the same selection: under the envelope the model returned the
-- whole enclosing function — the <before> and <after> context included — while the plain
-- contract returned exactly the selected lines. It is also the workaround this rebuild set out
-- to delete (README → *The contract*), and no envelope survives a code fragment whose braces do
-- not balance, which is most fragments.
local CONTRACT = [[
You are an inline code editor inside Neovim. The editor decides where your output goes;
you only supply code. Return ONLY the replacement text for the selected region.
Reproduce every line you are not changing exactly as given. Do not add commentary.]]

local NO_TOOLS = "You have no tools. Work only from the text below."
local DEEP = [[
You may read files in this repository to learn its conventions before answering.
Do not modify any file: the editor applies your output, not you.]]

local INSERT = [[
The selected region is empty. Return only the new code to insert at that point.]]

---@param bufnr number
---@param range table
---@return string
local function diagnostics_for(bufnr, range)
	local out = {}
	for _, d in ipairs(vim.diagnostic.get(bufnr)) do
		if d.lnum >= range.s0 and d.lnum <= math.max(range.s0, range.e0 - 1) then
			table.insert(
				out,
				("line %d: %s"):format(d.lnum + 1, vim.split(d.message, "\n", { plain = true })[1])
			)
		end
	end
	return table.concat(out, "\n")
end

---@param bufnr number
---@param range table
---@param instruction string
---@param deep boolean
---@return { prompt: string, instruction: string, content: string, selection: string[] }
local function build_prompt(bufnr, range, instruction, deep)
	local total = api.nvim_buf_line_count(bufnr)
	local filetype = vim.bo[bufnr].filetype
	local path = vim.fn.fnamemodify(api.nvim_buf_get_name(bufnr), ":.")

	local selection = api.nvim_buf_get_lines(bufnr, range.s0, range.e0, false)
	local before = api.nvim_buf_get_lines(bufnr, math.max(0, range.s0 - CONTEXT_LINES), range.s0, false)
	local after = api.nvim_buf_get_lines(bufnr, range.e0, math.min(total, range.e0 + CONTEXT_LINES), false)

	local head = { CONTRACT, deep and DEEP or NO_TOOLS }
	if not range.has_selection then
		table.insert(head, INSERT)
	end

	local content = {
		("<file path=%s filetype=%s lines=%d-%d>"):format(
			path ~= "" and path or "[no name]",
			filetype ~= "" and filetype or "text",
			range.s0 + 1,
			range.e0
		),
		"<before>",
		table.concat(before, "\n"),
		"</before>",
		"<selection>",
		table.concat(selection, "\n"),
		"</selection>",
		"<after>",
		table.concat(after, "\n"),
		"</after>",
		"</file>",
	}

	local diagnostics = diagnostics_for(bufnr, range)
	if diagnostics ~= "" then
		table.insert(content, "<diagnostics>")
		table.insert(content, diagnostics)
		table.insert(content, "</diagnostics>")
	end

	local instruction_block = table.concat(head, "\n\n") .. "\n\nInstruction: " .. instruction
	local content_block = table.concat(content, "\n")

	return {
		instruction = instruction_block,
		content = content_block,
		prompt = instruction_block .. "\n\n" .. content_block .. "\n",
		-- Kept for the parser: a reply that reuses lines of the selection is an edit, however
		-- little it looks like code on its own.
		selection = selection,
	}
end

--=============================================================================
-- Diff keymaps
--=============================================================================

---@param bufnr number
---@return table|nil
local function diff_under_cursor(bufnr)
	local diffs = buf_state(bufnr).diffs
	local row = api.nvim_win_get_cursor(0)[1] - 1

	local only
	for _, d in pairs(diffs) do
		local s0, e0 = resolve(bufnr, d.marks)
		if s0 and row >= s0 and row <= math.max(s0, e0) then
			return d
		end
		only = only == nil and d or false
	end
	-- Outside every diff, but if only one is pending the intent is unambiguous
	return only or nil
end

local function bind_diff_keys(bufnr)
	local shared = require("codecompanion.config").interactions.shared.keymaps

	-- DiffUI binds these two buffer-locally even when skipping default keymaps, shadowing the
	-- core paragraph motions while a diff is pending — and the second concurrent diff clobbers
	-- the first's. Ours dispatch by cursor position instead.
	pcall(vim.keymap.del, "n", shared.next_hunk.modes.n, { buffer = bufnr })
	pcall(vim.keymap.del, "n", shared.previous_hunk.modes.n, { buffer = bufnr })
	-- Delete the literal keys too, in case upstream changes the shared-keymap structure and the
	-- reads above silently find nothing. These are the stock defaults; harmless if not bound.
	pcall(vim.keymap.del, "n", "}", { buffer = bufnr })
	pcall(vim.keymap.del, "n", "{", { buffer = bufnr })

	local function on(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = bufnr, desc = desc, nowait = true })
	end

	on("g2", function()
		M.accept(bufnr)
	end, "AI: accept the diff under the cursor")
	on("g3", function()
		M.reject(bufnr)
	end, "AI: reject the diff under the cursor")
	on("<leader>cj", function()
		M.hunk(bufnr, "next")
	end, "AI: next hunk in the diff under the cursor")
	on("<leader>ck", function()
		M.hunk(bufnr, "previous")
	end, "AI: previous hunk in the diff under the cursor")
end

local function unbind_diff_keys(bufnr)
	for _, lhs in ipairs({ "g2", "g3", "<leader>cj", "<leader>ck" }) do
		pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
	end
end

--=============================================================================
-- Registry bookkeeping
--=============================================================================

local function forget_request(req)
	local st = buf_state(req.bufnr)
	st.requests[req.id] = nil
	if req.progress then
		req.progress.stop()
	end
end

---@param diff table
---@param keep_marks? boolean The reject path still needs them after this returns
local function forget_diff(diff, keep_marks)
	local st = buf_state(diff.bufnr)
	st.diffs[diff.id] = nil
	if not keep_marks then
		drop_marks(diff.bufnr, diff.marks)
	end
	-- resolve_diff clears every shared keymap in the buffer, including the g2/g3 we own, so a
	-- second pending diff would silently lose its bindings.
	vim.schedule(function()
		if not api.nvim_buf_is_valid(diff.bufnr) then
			return
		end
		if count(buf_state(diff.bufnr).diffs) > 0 then
			bind_diff_keys(diff.bufnr)
		else
			unbind_diff_keys(diff.bufnr)
		end
	end)
end

---Auto-reject on premature close is disabled under skip_default_keymaps, so restoring the
---original lines is ours to do.
---@param bufnr number
local function watch_buffer(bufnr)
	local st = buf_state(bufnr)
	if st.augroup then
		return
	end
	st.augroup = api.nvim_create_augroup("AiInlineBuf" .. bufnr, { clear = true })

	local function reject_pending()
		-- Snapshot first: rejecting mutates st.diffs while we walk it
		for _, diff in ipairs(vim.tbl_values(st.diffs)) do
			M.reject(bufnr, diff)
		end
	end

	api.nvim_create_autocmd("WinClosed", {
		group = st.augroup,
		buffer = bufnr,
		callback = function(args)
			-- WinClosed's pattern is a window id, so `buffer =` scopes this to "a window showing
			-- this buffer closed" — not "the buffer went away". Without the count below, closing
			-- one split of two throws away a finished edit the user had not accepted yet.
			-- WinClosed fires before the window is gone, so the closing one still counts.
			-- Deferred: a fast split/close cycle can fire WinClosed before the new window for the
			-- same buffer exists, so checking immediately would count zero and reject.
			local closing = tonumber(args.match)
			vim.defer_fn(function()
				for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
					if win ~= closing then
						return
					end
				end
				reject_pending()
			end, 50)
		end,
	})

	api.nvim_create_autocmd({ "BufDelete", "BufUnload" }, {
		group = st.augroup,
		buffer = bufnr,
		callback = function()
			reject_pending()
			-- A request whose buffer is gone has nowhere to land, and on_reply would discard it
			-- anyway — so stop paying for it rather than letting the agent finish into a void.
			for _, req in ipairs(vim.tbl_values(st.requests)) do
				if req.handle then
					pcall(req.handle.cancel)
				end
				forget_request(req)
			end
			-- Neither the registry entry nor the augroup is reachable again once the buffer is
			-- wiped, and both would otherwise accumulate for the rest of the session.
			pcall(api.nvim_del_augroup_by_id, st.augroup)
			buffers[bufnr] = nil
		end,
	})
end

--=============================================================================
-- Applying a reply
--=============================================================================

---@param req table
---@param result ai.parse.Result
local function show_diff(req, result)
	local lines = result.lines
	local bufnr = req.bufnr
	local s0, e0 = resolve(bufnr, req.marks)
	if not s0 then
		drop_marks(bufnr, req.marks)
		return vim.notify(
			"[ai] the anchored range was deleted while the request was in flight — result dropped",
			vim.log.levels.WARN
		)
	end

	local from_lines = api.nvim_buf_get_lines(bufnr, 0, -1, true)
	local to_lines = {}
	vim.list_extend(to_lines, vim.list_slice(from_lines, 1, s0))
	vim.list_extend(to_lines, lines)
	vim.list_extend(to_lines, vim.list_slice(from_lines, e0 + 1))

	if vim.deep_equal(from_lines, to_lines) then
		drop_marks(bufnr, req.marks)
		-- A model that declines usually echoes the selection back inside a fence and explains
		-- itself around it. Reporting only "nothing to change" would throw that explanation away
		-- and leave the user staring at an unchanged buffer with no idea why.
		if result.preamble then
			return ui.message({
				bufnr = bufnr,
				row = s0,
				title = ("%s — returned the selection unchanged"):format(req.provider),
				text = result.preamble,
				on_confirm = function()
					if not api.nvim_buf_is_valid(bufnr) then
						return vim.notify("[ai] source buffer was closed — cannot open chat", vim.log.levels.WARN)
					end
					require("ai.chat").open_with_context({
						messages = {
							{ role = "user", content = ("[ai (inline)] %s\n\n%s"):format(
								req.instruction,
								table.concat(req.selection or {}, "\n")
							) },
							-- result.preamble, not result.text: kind "code" has no text field,
							-- only the prose that surrounded the fence.
							{ role = "llm", content = result.preamble },
						},
					})
				end,
			})
		end
		return vim.notify("[ai] the reply matches the buffer — nothing to change", vim.log.levels.INFO)
	end

	-- An empty buffer never reaches the diff UI. DiffUI's own create_diff_display writes the
	-- merged old-and-new view straight in when it finds the buffer empty (diff/ui.lua:439), and
	-- apply_inline then applies its hunks on top of that — so the reply lands twice. There is
	-- nothing to compare against in an empty buffer anyway, and `u` is a complete way back.
	if api.nvim_buf_line_count(bufnr) == 1 and (api.nvim_buf_get_lines(bufnr, 0, 1, true)[1] or "") == "" then
		drop_marks(bufnr, req.marks)
		api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		return vim.notify("[ai] the buffer was empty, so the reply was inserted directly — u to undo")
	end

	-- The diff UI takes over a window to show itself, and falls back to the *current* one when
	-- the target buffer is not on screen (diff/ui.lua:426), which would yank whatever the user
	-- moved on to read out from under them. Requests run for seconds, so moving on is normal.
	if vim.fn.bufwinid(bufnr) == -1 then
		drop_marks(bufnr, req.marks)
		return vim.notify(
			("[ai] %s answered, but %s is no longer on screen — nothing was applied, run it again with the buffer visible"):format(
				req.provider,
				vim.fn.fnamemodify(api.nvim_buf_get_name(bufnr), ":t"):gsub("^$", "the target buffer")
			),
			vim.log.levels.WARN
		)
	end

	local original = vim.list_slice(from_lines, s0 + 1, e0)

	-- Placed before show_diff and tracked through it: the change is confined to [start, finish),
	-- start holds against insertion and finish is pushed past the replacement, so the pair spans
	-- exactly the new content once the diff has been applied.
	local srow, scol = clamp(bufnr, s0)
	local erow, ecol, ends_at_eof = clamp(bufnr, e0)
	local marks = {
		ends_at_eof = ends_at_eof,
		start = api.nvim_buf_set_extmark(bufnr, ANCHOR, srow, scol, { right_gravity = false }),
		finish = api.nvim_buf_set_extmark(bufnr, ANCHOR, erow, ecol, { right_gravity = true }),
	}

	seq = seq + 1
	local diff = {
		id = seq,
		bufnr = bufnr,
		marks = marks,
		original = original,
		provider = req.provider,
	}

	local helpers = require("codecompanion.helpers")
	diff.ui = helpers.show_diff({
		bufnr = bufnr,
		from_lines = from_lines,
		to_lines = to_lines,
		diff_id = diff.id,
		ft = vim.bo[bufnr].filetype,
		inline = true,
		banner = "g2 Accept | g3 Reject | <leader>cj/ck Hunk",
		-- What lets us own g2/g3, which is what makes concurrent diffs possible at all
		skip_default_keymaps = true,
		keymaps = {
			on_accept = function()
				forget_diff(diff)
			end,
			on_reject = function()
				-- Deferred past resolve_diff's own cleanup. When a hunk starts at line 1, DiffUI
				-- inserts a real spacer line at row 0 and deletes it again in clear(), which runs
				-- after this handler — restoring first made that deletion land on a line of ours
				-- and silently swallow it.
				vim.schedule(function()
					local rs, re = resolve(bufnr, diff.marks)
					if rs and api.nvim_buf_is_valid(bufnr) then
						-- Only this diff's region, never the whole buffer: a whole-buffer restore
						-- is what makes the built-in corrupt a second concurrent request.
						pcall(api.nvim_buf_set_lines, bufnr, rs, math.max(rs, re), false, diff.original)
					end
					drop_marks(bufnr, diff.marks)
				end)
				forget_diff(diff, true)
			end,
		},
	})

	drop_marks(bufnr, req.marks)
	buf_state(bufnr).diffs[diff.id] = diff
	watch_buffer(bufnr)
	bind_diff_keys(bufnr)
end

---@param req table
---@param reply string
local function on_reply(req, reply)
	forget_request(req)
	if not api.nvim_buf_is_valid(req.bufnr) then
		return
	end

	-- The filetype and the original selection are what keep the parser from mistaking a correct
	-- reply for prose: in a Markdown buffer the right answer *is* a sentence, and a reply that
	-- echoes lines of the selection is an edit whatever it looks like in isolation.
	local result = parse.parse(reply, { filetype = vim.bo[req.bufnr].filetype, selection = req.selection })

	if result.kind == "code" then
		return show_diff(req, result)
	end

	if result.kind == "noop" then
		drop_marks(req.bufnr, req.marks)
		return vim.notify(("[ai] %s"):format(result.reason), vim.log.levels.WARN)
	end

	local s0 = resolve(req.bufnr, req.marks) or 0
	drop_marks(req.bufnr, req.marks)
	ui.message({
		bufnr = req.bufnr,
		row = s0,
		title = ("%s — %s"):format(req.provider, result.reason),
		text = result.text,
		on_confirm = function()
			if not api.nvim_buf_is_valid(req.bufnr) then
				return vim.notify("[ai] source buffer was closed — cannot open chat", vim.log.levels.WARN)
			end
			require("ai.chat").open_with_context({
				messages = {
					{ role = "user", content = ("[ai (inline)] %s\n\n%s"):format(
						req.instruction,
						table.concat(req.selection or {}, "\n")
					) },
					{ role = "llm", content = result.text },
				},
			})
		end,
	})
end

--=============================================================================
-- Public entry points
--=============================================================================

---Start one inline request. Separated from M.run so it can be driven without the input float,
---which is also what the harness in _codecompanion's step 03 checks drive.
---@param opts { bufnr: number, range: table, instruction: string, deep?: boolean, timeout?: number }
---@return table|nil req
function M.submit(opts)
	local bufnr = opts.bufnr
	if not api.nvim_buf_is_valid(bufnr) then
		return nil
	end

	local selection = providers.current("inline")
	local transport = providers.transport(selection.provider, opts.deep or false)

	-- Repeated from M.run because this is a public entry point in its own right, and a deep
	-- request on a transport that cannot read would otherwise silently run as a shallow one.
	if opts.deep and not providers.transports[transport].read then
		vim.notify(
			("[ai] %s uses the %s transport, which cannot read the repository — <leader>cm to switch"):format(selection.provider, transport),
			vim.log.levels.WARN
		)
		return nil
	end

	seq = seq + 1
	local req = {
		id = seq,
		bufnr = bufnr,
		provider = selection.provider,
		transport = transport,
		marks = anchor(bufnr, opts.range),
	}

	local built = build_prompt(bufnr, opts.range, opts.instruction, opts.deep or false)
	req.selection = built.selection
	req.progress = ui.progress(bufnr, function()
		return resolve(bufnr, req.marks)
	end, ("%s · %s · %s"):format(selection.provider, tostring(selection.opts.model), opts.instruction))

	local module = transport == "http" and "ai.inline.http"
		or transport == "relay" and "ai.inline.relay"
		or "ai.inline.acp"

	-- Registered before the send, not after. A transport can fail synchronously — no
	-- `opencode-llm` on PATH, an adapter that will not resolve — and its on_error runs inside
	-- send(); registering afterwards would put an already-dead request into the buffer's registry
	-- with nothing left to clear it, so `<leader>cx` would keep reporting a phantom in flight.
	buf_state(bufnr).requests[req.id] = req
	watch_buffer(bufnr)

	req.handle = require(module).send({
		prompt = built.prompt,
		instruction = built.instruction,
		content = built.content,
		provider = selection.provider,
		bufnr = bufnr,
		timeout = opts.timeout,
	}, {
		on_done = function(reply)
			on_reply(req, reply)
		end,
		on_error = function(msg)
			forget_request(req)
			drop_marks(bufnr, req.marks)
			vim.notify("[ai] " .. msg, vim.log.levels.ERROR)
		end,
		on_tool = function(name)
			if req.progress then
				req.progress.set_label(("%s · %s"):format(selection.provider, name))
			end
		end,
	})

	return req
end

---@param deep boolean True for <leader>cI, which invites repo research
function M.run(deep)
	local bufnr = api.nvim_get_current_buf()
	local range = capture_range()
	local selection = providers.current("inline")
	local transport = providers.transport(selection.provider, deep)

	if deep and not providers.transports[transport].read then
		return vim.notify(
			("[ai] <leader>cI needs a transport that can read the repository. %s uses %s, which cannot — "):format(
				selection.provider,
				transport
			) .. "it works on claude and on opencode. Switch with <leader>cm.",
			vim.log.levels.WARN
		)
	end

	input.open({
		title = (" Inline — %s · %s%s "):format(
			selection.provider,
			tostring(selection.opts.model),
			deep and " · repo reads" or ""
		),
		on_submit = function(text)
			if not text or vim.trim(text) == "" then
				return
			end
			M.submit({ bufnr = bufnr, range = range, instruction = vim.trim(text), deep = deep })
		end,
	})
end

---@param bufnr? number
---@param diff? table Resolve this diff instead of the one under the cursor
function M.accept(bufnr, diff)
	bufnr = bufnr or api.nvim_get_current_buf()
	diff = diff or diff_under_cursor(bufnr)
	if not diff then
		return vim.notify("[ai] no diff here", vim.log.levels.WARN)
	end
	require("codecompanion.diff.keymaps").accept_change.callback(diff.ui)
end

---@param bufnr? number
---@param diff? table
function M.reject(bufnr, diff)
	bufnr = bufnr or api.nvim_get_current_buf()
	diff = diff or diff_under_cursor(bufnr)
	if not diff then
		return vim.notify("[ai] no diff here", vim.log.levels.WARN)
	end
	require("codecompanion.diff.keymaps").reject_change.callback(diff.ui)
end

---@param bufnr number
---@param direction "next"|"previous"
function M.hunk(bufnr, direction)
	local diff = diff_under_cursor(bufnr)
	if not diff then
		return vim.notify("[ai] no diff here", vim.log.levels.WARN)
	end
	local keymaps = require("codecompanion.diff.keymaps")
	local handler = direction == "next" and keymaps.next_hunk or keymaps.previous_hunk
	-- The handler reads the cursor out of diff_ui.winnr, captured when the diff was created and
	-- never revalidated, so a since-closed window would raise instead of reporting.
	if not (diff.ui and diff.ui.winnr and api.nvim_win_is_valid(diff.ui.winnr)) then
		return vim.notify("[ai] the window this diff was rendered in is gone", vim.log.levels.WARN)
	end
	handler.callback(diff.ui)
end

---Cancel the request under the cursor, or every in-flight request in the buffer.
function M.cancel()
	local bufnr = api.nvim_get_current_buf()
	local st = buf_state(bufnr)
	local row = api.nvim_win_get_cursor(0)[1] - 1

	local targets = {}
	for _, req in pairs(st.requests) do
		local s0, e0 = resolve(bufnr, req.marks)
		if s0 and row >= s0 and row <= math.max(s0, e0) then
			targets = { req }
			break
		end
	end

	if #targets == 0 then
		-- Not over an inline request — if we're in a chat buffer, stop the agent
		local ft = vim.bo[bufnr].filetype
		if ft == "codecompanion" then
			return require("ai.chat").stop()
		end
		return vim.notify("[ai] nothing in flight in this buffer", vim.log.levels.INFO)
	end

	for _, req in ipairs(targets) do
		if req.handle then
			pcall(req.handle.cancel)
		end
		forget_request(req)
		drop_marks(bufnr, req.marks)
	end
	vim.notify(("[ai] cancelled %d request(s)"):format(#targets))
end

---Switch the inline backend and model. The full option UX is the status panel's job (step 05);
---this is the minimum needed to exercise every transport.
function M.pick()
	local names = vim.tbl_keys(providers.providers)
	table.sort(names)

	vim.ui.select(names, { prompt = "Inline provider" }, function(provider)
		if not provider then
			return
		end

		-- Committed only once a model has been picked: abandoning the second prompt used to leave
		-- the provider switched, which is a change the user did not finish asking for.
		local function commit(model, extra)
			providers.set_provider("inline", provider)
			for key, value in pairs(extra or {}) do
				providers.set_option("inline", key, value)
			end
			if model then
				providers.set_option("inline", "model", model)
			end
			require("ai.acp_pool").drain_provider(providers.current("inline").provider)
			local current = providers.current("inline")
			vim.notify(("[ai] inline → %s · %s"):format(provider, tostring(current.opts.model)))
		end

		local function choose_model(list, extra)
			vim.ui.select(list, { prompt = provider .. " model" }, function(model)
				if not model then
					return
				end
				commit(model, extra)
			end)
		end

		if provider == "opencode" then
			return choose_model(providers.opencode_models())
		end
		if provider == "claude" then
			return choose_model(providers.providers.claude.options.model.values)
		end

		vim.ui.select({ "cloud", "local" }, { prompt = "ollama endpoint" }, function(endpoint)
			if not endpoint then
				return
			end
			providers.ollama_models(endpoint, function(models, err)
				if not models then
					return vim.notify("[ai] " .. err, vim.log.levels.ERROR)
				end
				choose_model(models, { endpoint = endpoint })
			end)
		end)
	end)
end

---How many requests and diffs this buffer is carrying. Handy when checking by hand whether
---something is still in flight or a diff was left behind.
---@param bufnr number
---@return { requests: number, diffs: number }
function M.stats(bufnr)
	local st = buf_state(bufnr)
	return { requests = count(st.requests), diffs = count(st.diffs) }
end

return M
