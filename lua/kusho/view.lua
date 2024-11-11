local M = {}
local log = require("kusho").log

-- Default options for buffer creation
M.default_buf_options = {
	buftype = "nofile",
	bufhidden = "wipe",
	swapfile = false,
	buflisted = false,
	modifiable = true,
	filetype = "kusho",
}

-- Default options for window creation
M.default_win_options = {
	wrap = false,
	cursorline = true,
	number = true,
	relativenumber = false,
}

-- Create a new buffer with given options
function M.create_buffer(options)
	options = vim.tbl_extend("force", M.default_buf_options, options or {})

	log.debug("Creating new buffer with options:", vim.inspect(options))

	local bufnr = vim.api.nvim_create_buf(false, true)

	for option, value in pairs(options) do
		vim.api.nvim_buf_set_option(bufnr, option, value)
	end

	return bufnr
end

-- Set content in a buffer
function M.set_buffer_content(bufnr, content)
	log.debug("Setting buffer content")

	-- Ensure content is a table/array of lines
	local lines = type(content) == "table" and content or { content }

	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

-- Create a window with given options
function M.create_window(options)
	options = vim.tbl_extend("force", M.default_win_options, options or {})

	log.debug("Creating new window with options:", vim.inspect(options))

	-- Create the split
	vim.cmd("vsplit")
	local win_id = vim.api.nvim_get_current_win()

	for option, value in pairs(options) do
		vim.api.nvim_win_set_option(win_id, option, value)
	end

	return win_id
end

-- Display content in a new window
function M.display_in_window(content, buf_options, win_options)
	-- Create buffer and window
	local bufnr = M.create_buffer(buf_options)
	local win_id = M.create_window(win_options)

	-- Set the buffer in the window
	vim.api.nvim_win_set_buf(win_id, bufnr)

	-- Set the content
	M.set_buffer_content(bufnr, content)

	return bufnr, win_id
end

function M.create_split()
	vim.cmd("vsplit")
	return vim.api.nvim_get_current_win()
end

return M
