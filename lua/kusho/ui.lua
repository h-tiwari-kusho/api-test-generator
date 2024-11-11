local M = {}
local view = require("kusho.view")
local log = require("kusho").log

-- Format HTTP request details into displayable lines
function M.format_request_details(request)
	local lines = {
		"HTTP Request Details",

		"==================",
		string.format("Method: %s", request.method or "N/A"),
		string.format("URL: %s", request.url or "N/A"),
		"",
	}

	-- Add headers if present
	if next(request.headers) then
		table.insert(lines, "Headers:")
		table.insert(lines, "--------")
		for name, value in pairs(request.headers) do
			table.insert(lines, string.format("%s: %s", name, value))
		end
		table.insert(lines, "")
	end

	-- Add body if present
	if request.body then
		table.insert(lines, "Body:")
		table.insert(lines, "-----")
		-- Split body into lines
		for line in request.body:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end
	end

	return lines
end

-- Display HTTP request details in a new window
function M.display_request(request)
	if not request then
		log.warn("No request data to display")
		vim.notify("No request data to display", vim.log.levels.WARN)
		return
	end

	-- Create buffer
	local buf = view.create_buffer()

	-- Format and set content
	local lines = M.format_request_details(request)
	view.set_buffer_content(buf, lines)

	-- Create split and set buffer
	local win = view.create_split()
	vim.api.nvim_win_set_buf(win, buf)

	return buf, win
end

---@class Response
---@field status number
---@field headers table<string, string>
---@field body string
---@field raw string

---@param headers table<string, string>
---@return string
function M.format_response_headers(headers)
	local formatted = {}
	for name, value in pairs(headers) do
		table.insert(formatted, string.format("%s: %s", name, value))
	end
	return table.concat(formatted, "\n")
end

function M.table_to_string(tbl)
	local parts = {}
	for name, value in pairs(tbl) do
		table.insert(parts, string.format("%s=%s", name, tostring(value)))
	end
	return table.concat(parts, ",")
end

---@param response Response
---@return  table
function M.format_response(response)
	local parts = {
		"### Response ###",
		string.format("Status: %d", response.status),
		"",
	}

	-- Add headers if present
	if next(response.headers) then
		table.insert(parts, "Headers:")
		table.insert(parts, "--------")
		for name, value in pairs(response.headers) do
			table.insert(parts, string.format("%s: %s", name, value))
		end
		table.insert(parts, "")
	end
	log.debug("Response Body", response.body, type(response.body))

	if response.body then
		table.insert(parts, "Body:")
		table.insert(parts, "--------")
		table.insert(parts, M.table_to_string(response.body))
	end
	return parts
end

function M.display_response(response)
	-- Format response
	local formatted_response_lines = M.format_response({
		status = response.status,
		headers = response.headers,
		body = response.body,
		raw = response.raw,
	})
	if not formatted_response_lines then
		log.warn("No request data to display")
		vim.notify("No request data to display", vim.log.levels.WARN)
		return
	end

	-- Create buffer
	local buf = view.create_buffer()

	log.debug("Formateed", formatted_response_lines)

	-- Format and set content
	view.set_buffer_content(buf, formatted_response_lines)

	-- Create split and set buffer
	local win = view.create_split()
	vim.api.nvim_win_set_buf(win, buf)

	return buf, win
end

-- Display logs in a new window
function M.display_logs()
	local log_file = string.format("%s/kusho.log", vim.fn.stdpath("cache"))

	-- Try to read the log file
	local lines = {}
	local file = io.open(log_file, "r")
	if file then
		for line in file:lines() do
			table.insert(lines, line)
		end
		file:close()
	else
		lines = { "No logs found or unable to read log file" }
	end

	-- Custom options for log display
	local buf_options = {
		filetype = "kusho-log",
		modifiable = false,
	}

	local win_options = {
		wrap = false,
		cursorline = true,
		number = true,
	}

	return view.display_in_window(lines, buf_options, win_options)
end

function M.create_status_window()
	local bufnr = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = "rounded",
	}

	local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)

	return {
		bufnr = bufnr,
		winnr = winnr,
		update = function(message)
			vim.schedule(function()
				vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { message })
			end)
		end,
		close = function()
			vim.api.nvim_win_close(winnr, true)
		end,
	}
end

return M
