-- Turn an arbitrary agent reply into either code to place or a decision not to touch the
-- buffer. This is the component that keeps prose, refusals and failed tool attempts out of
-- source files, so it errs towards refusing: a rejected edit costs a keystroke, an inserted
-- paragraph costs a file.

local M = {}

---@class ai.parse.Result
---@field kind "code"|"prose"|"noop"
---@field lines string[]|nil Replacement lines, when kind == "code"
---@field text string|nil The reply as prose, when kind ~= "code"
---@field reason string|nil Why the reply was not treated as code
---@field fenced boolean Whether the code came out of a fenced block

-- A failed tool attempt that nothing parsed, leaking into the message as text. Measured on
-- opencode under a deny-everything permission set; the markup is unfenced.
local LEAK_PATTERNS = { "<tool_call>", "</tool_call>", "<function=", "<parameter=" }

local function split(text)
	return vim.split(text, "\n", { plain = true })
end

---Locate the first fenced block. Returns the body lines, or nil when there is no fence.
---@param lines string[]
---@return string[]|nil body
---@return string[] outside Lines that were not part of the block
local function first_fence(lines)
	local open
	for i, line in ipairs(lines) do
		if line:match("^%s*```") then
			open = i
			break
		end
	end
	if not open then
		return nil, lines
	end

	local close
	for i = open + 1, #lines do
		if lines[i]:match("^%s*```%s*$") then
			close = i
			break
		end
	end
	-- An unterminated fence means a truncated reply. Take the rest rather than discarding it;
	-- the caller still gets a chance to reject it as prose.
	close = close or (#lines + 1)

	local body, outside = {}, {}
	for i = open + 1, close - 1 do
		table.insert(body, lines[i])
	end
	for i = 1, #lines do
		if i < open or i > close then
			table.insert(outside, lines[i])
		end
	end
	return body, outside
end

---@param lines string[]
---@return string|nil marker
local function find_leak(lines)
	local joined = table.concat(lines, "\n")
	for _, pattern in ipairs(LEAK_PATTERNS) do
		if joined:find(pattern, 1, true) then
			return pattern
		end
	end
end

local function is_blank(lines)
	for _, line in ipairs(lines) do
		if vim.trim(line) ~= "" then
			return false
		end
	end
	return true
end

---Does a line read as code rather than as a sentence?
---@param line string
---@return boolean
local function looks_like_code(line)
	local trimmed = vim.trim(line)
	if trimmed == "" then
		return false
	end
	-- Markdown structure is the clearest prose tell: headings, bullets, numbered lists
	if trimmed:match("^#+%s") or trimmed:match("^[%-%*]%s") or trimmed:match("^%d+%.%s") then
		return false
	end
	-- Bold/italic runs and inline-code spans belong to explanations, not to source
	if trimmed:match("%*%*") or trimmed:match("`[^`]+`") then
		return false
	end
	-- Indentation is code's own signal, and prose replies are not indented
	if line:match("^[ \t]+") then
		return true
	end
	if trimmed:match("^//") or trimmed:match("^%-%-") or trimmed:match("^#") then
		return true
	end
	-- Assignment, call, block or terminator punctuation
	if trimmed:match("[{}%[%]();]") or trimmed:match("[%w_%)%]\"']%s*=%s*") or trimmed:match("=>") then
		return true
	end
	-- A sentence: several words, ending in sentence punctuation
	if trimmed:match("[%.%?!:]$") and select(2, trimmed:gsub("%s+", "")) >= 3 then
		return false
	end
	return false
end

---@param lines string[]
---@return boolean
local function reads_as_prose(lines)
	local total, code = 0, 0
	for _, line in ipairs(lines) do
		if vim.trim(line) ~= "" then
			total = total + 1
			if looks_like_code(line) then
				code = code + 1
			end
		end
	end
	if total == 0 then
		return false
	end
	return (code / total) < 0.5
end

---Parse an agent reply.
---@param reply string
---@return ai.parse.Result
function M.parse(reply)
	reply = reply or ""
	local lines = split(reply)

	local body, outside = first_fence(lines)

	-- Checked outside the fence on purpose. The measured leak is unfenced message text, and
	-- searching the whole reply would reject legitimate code that merely contains the markup
	-- as a string — including this repository's own fixtures.
	local marker = find_leak(outside)
	if marker then
		return {
			kind = "prose",
			text = reply,
			reason = ("the reply contains %s markup — a failed tool attempt, not code"):format(marker),
			fenced = body ~= nil,
		}
	end

	if body then
		if is_blank(body) then
			return {
				kind = "noop",
				text = reply,
				reason = "the reply's code block is empty",
				fenced = true,
			}
		end
		return { kind = "code", lines = body, fenced = true }
	end

	if is_blank(lines) then
		return { kind = "noop", text = reply, reason = "the reply is empty", fenced = false }
	end

	if reads_as_prose(lines) then
		return {
			kind = "prose",
			text = reply,
			reason = "the reply reads as prose rather than code",
			fenced = false,
		}
	end

	return { kind = "code", lines = lines, fenced = false }
end

return M
