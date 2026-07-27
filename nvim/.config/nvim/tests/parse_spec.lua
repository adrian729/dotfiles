-- Specs for ai.inline.parse, run over replies recorded from real agents.
--
--   cd ~/.config/nvim && nvim --headless -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }"
--
-- Use the directory runner, not PlenaryBustedFile: the file runner spawns a child nvim without
-- -u, so the child loads the real config and buries the results in unrelated plugin errors.
--
-- Every fixture in tests/fixtures/ is a verbatim agent reply, not an invented one, apart from
-- _selection.txt, which is the input those replies were asked to edit. The point is to pin
-- behaviour that has already varied between agent versions and ambient models.

local parse = require("ai.inline.parse")

local FIXTURES = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures"

local function fixture(name)
	local path = FIXTURES .. "/" .. name
	assert.is_true(vim.fn.filereadable(path) == 1, "missing fixture: " .. path)
	return table.concat(vim.fn.readfile(path), "\n")
end

describe("ai.inline.parse", function()
	describe("fenced replies", function()
		it("drops the prose claude prefixes when tools are on", function()
			local result = parse.parse(fixture("claude_fenced_prose.txt"))
			assert.equals("code", result.kind)
			assert.is_true(result.fenced)
			assert.equals("-- Smoke harness for the connection pool.", result.lines[1])
			-- the explanation above the fence is gone
			for _, line in ipairs(result.lines) do
				assert.is_nil(line:find("Renamed the local function", 1, true))
			end
		end)

		it("extracts a fenced reply that carries no prose", function()
			local result = parse.parse(fixture("claude_verbatim.txt"))
			assert.equals("code", result.kind)
			assert.is_true(result.fenced)
			assert.is_nil(result.lines[1]:find("```", 1, true))
			assert.is_nil(result.lines[#result.lines]:find("```", 1, true))
		end)

		it("extracts a short fenced fragment", function()
			local result = parse.parse(fixture("opencode_fenced.txt"))
			assert.equals("code", result.kind)
			assert.same({ "local function format_seconds(ms)" }, result.lines)
		end)

		it("takes only the first block when several are present", function()
			local result = parse.parse("```lua\nfirst()\n```\nand also\n```lua\nsecond()\n```")
			assert.same({ "first()" }, result.lines)
		end)

		it("treats a fence with an empty body as a no-op, not an empty edit", function()
			local result = parse.parse("```lua\n\n```")
			assert.equals("noop", result.kind)
		end)
	end)

	describe("bare replies", function()
		it("takes an unfenced reply as code", function()
			local result = parse.parse(fixture("ollama_bare.txt"))
			assert.equals("code", result.kind)
			assert.is_false(result.fenced)
			assert.equals("-- Smoke harness for the connection pool.", result.lines[1])
		end)

		it("treats an empty reply as a no-op", function()
			assert.equals("noop", parse.parse("").kind)
			assert.equals("noop", parse.parse("\n  \n\t\n").kind)
		end)
	end)

	describe("replies that must never reach the buffer", function()
		it("rejects an answered question", function()
			local result = parse.parse(fixture("claude_question.txt"))
			assert.equals("prose", result.kind)
			assert.is_not_nil(result.reason)
		end)

		it("rejects a refusal", function()
			local result = parse.parse(fixture("claude_refusal.txt"))
			assert.equals("prose", result.kind)
		end)

		it("rejects leaked tool-call markup", function()
			local result = parse.parse(fixture("opencode_tool_call_leak.txt"))
			assert.equals("prose", result.kind)
			assert.is_not_nil(result.reason:find("<tool_call>", 1, true))
		end)

		it("still accepts code that merely mentions the markup inside a fence", function()
			local result = parse.parse('```lua\nlocal LEAK = { "<tool_call>", "<function=" }\n```')
			assert.equals("code", result.kind)
		end)

		it("rejects leaked markup that sits outside a fence", function()
			local result = parse.parse("<tool_call>\n<function=grep>\n</function>\n</tool_call>\n```lua\nx()\n```")
			assert.equals("prose", result.kind)
		end)
	end)

	describe("the verbatim contract", function()
		it("round-trips a 40-line selection byte-identically apart from the rename", function()
			local original = vim.fn.readfile(FIXTURES .. "/_selection.txt")
			local result = parse.parse(fixture("claude_verbatim.txt"))

			assert.equals("code", result.kind)
			assert.equals(#original, #result.lines, "line count changed")

			for i, line in ipairs(original) do
				local returned = result.lines[i]
				local reversed = returned:gsub("format_seconds", "secs")
				assert.equals(line, reversed, ("line %d is not byte-identical"):format(i))
			end
		end)

		it("preserves tabs rather than converting them to spaces", function()
			local result = parse.parse(fixture("claude_verbatim.txt"))
			local tabbed = 0
			for _, line in ipairs(result.lines) do
				if line:find("^\t") then
					tabbed = tabbed + 1
				end
			end
			assert.is_true(tabbed > 0, "the fixture should contain tab-indented lines")
		end)

		it("does not add or drop a trailing newline", function()
			local result = parse.parse("a()\nb()")
			assert.same({ "a()", "b()" }, result.lines)
		end)
	end)
end)
