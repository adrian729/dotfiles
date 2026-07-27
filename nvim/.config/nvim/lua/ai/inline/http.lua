-- ollama over plain HTTP, local or cloud. Structurally tool-free: no tool plumbing exists on
-- this path, so the text-only contract is guaranteed rather than merely asked for.

local adapters = require("codecompanion.adapters")
local client = require("codecompanion.http")
local providers = require("ai.providers")

local M = {}

---@param ctx { prompt: string, bufnr: number }
---@param cb { on_done: fun(text: string), on_error: fun(msg: string) }
---@return table handle
function M.send(ctx, cb)
	local name = providers.http_adapter("inline")
	local ok, adapter = pcall(adapters.resolve, name)
	if not ok or not adapter then
		cb.on_error(("could not resolve the %s adapter"):format(name))
		return { cancel = function() end }
	end

	-- Inline needs one complete reply, not a stream of chunks to reassemble
	adapter.opts.stream = false

	-- The client invokes this callback twice on an HTTP error: once with the 4xx body as though
	-- it were a reply, then again with an error table. Settle on the first one that decides.
	local settled = false
	local function done(fn, arg)
		if settled then
			return
		end
		settled = true
		fn(arg)
	end

	---Body text of an error response, which providers use to explain themselves
	---@param data table|nil
	---@return string
	local function error_detail(data)
		local body = type(data) == "table" and data.body or nil
		if type(body) ~= "string" or body == "" then
			return ""
		end
		local ok, json = pcall(vim.json.decode, body)
		if ok and type(json) == "table" and type(json.error) == "string" then
			return json.error
		end
		return vim.trim(body):sub(1, 200)
	end

	local job = client.new({ adapter = adapter:map_schema_to_params() }):request({
		messages = adapter:map_roles({ { role = "user", content = ctx.prompt } }),
	}, {
		callback = function(err, data, resolved)
			if err then
				local msg = type(err) == "table" and (err.message or vim.inspect(err)) or tostring(err)
				local detail = error_detail(type(err) == "table" and err.stderr or nil)
				return done(cb.on_error, ("%s: %s%s"):format(name, vim.trim(msg), detail ~= "" and (" " .. detail) or ""))
			end
			if not data then
				return
			end

			-- Checked before the adapter's own parser, which assumes a well-formed reply and
			-- errors out indexing the error body instead
			local status = type(data) == "table" and data.status or nil
			if status and status >= 400 then
				local detail = error_detail(data)
				return done(
					cb.on_error,
					("%s: HTTP %d%s"):format(name, status, detail ~= "" and (" — " .. detail) or "")
				)
			end

			local ok, parsed = pcall(adapters.call_handler, resolved, "parse_inline", data, {})
			if not ok then
				return done(cb.on_error, ("%s: could not read the reply (%s)"):format(name, tostring(parsed)))
			end
			if not parsed then
				return done(cb.on_error, ("%s: no usable reply"):format(name))
			end
			if parsed.status ~= "success" then
				return done(cb.on_error, ("%s: %s"):format(name, tostring(parsed.output)))
			end
			done(cb.on_done, parsed.output)
		end,
	}, { bufnr = ctx.bufnr, interaction = "inline" })

	if not job then
		cb.on_error(("%s: the request could not be started"):format(name))
		return { cancel = function() end }
	end

	return {
		cancel = function()
			pcall(function()
				job.cancel()
			end)
		end,
	}
end

return M
