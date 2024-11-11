local M = {}
local log = require("kusho").log

function M.get_api_request_at_cursor()
	log.debug("Starting get_api_request_at_cursor")
	-- Get current cursor position
	local bufnr = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1 -- Convert to 0-based index

	log.debug(string.format("Cursor position - row: %d, col: %d", row, col))

	-- Get parser and tree
	local parser = vim.treesitter.get_parser(bufnr, "http")
	if not parser then
		log.error("Failed to get HTTP parser")
		return nil
	end

	local tree = parser:parse()[1]
	local root = tree:root()
	log.debug("Successfully got parser and tree")

	-- Find the section containing cursor position
	local section_node = nil
	local cursor_pos = { row, col }

	-- Query to find sections
	local query = vim.treesitter.query.parse(
		"http",
		[[
        (section) @section
    ]]
	)

	log.debug("Starting section search")
	for _, match in query:iter_matches(root, bufnr) do
		for id, node in pairs(match) do
			local start_row, start_col, end_row, end_col = node:range()
			if cursor_pos[1] >= start_row and cursor_pos[1] <= end_row then
				section_node = node
				log.debug(
					string.format("Found section at range: %d,%d - %d,%d", start_row, start_col, end_row, end_col)
				)
				break
			end
		end
		if section_node then
			break
		end
	end

	if not section_node then
		log.warn("No section found at cursor position")
		return nil
	end

	-- Find request node within section
	local request_node = nil
	for child in section_node:iter_children() do
		if child:type() == "request" then
			request_node = child
			break
		end
	end

	if not request_node then
		log.warn("No request found in section")
		return nil
	end

	-- Extract request details
	local result = {
		method = nil,
		url = nil,
		headers = {},
		body = nil,
	}

	log.debug("Extracting request details")

	-- Get method and URL
	for child in request_node:iter_children() do
		if child:type() == "method" then
			result.method = vim.treesitter.get_node_text(child, bufnr)
			log.debug("Found method: " .. result.method)
		elseif child:type() == "target_url" then
			result.url = vim.treesitter.get_node_text(child, bufnr)
			log.debug("Found URL: " .. result.url)
		elseif child:type() == "header" then
			-- Extract header name and value
			for header_part in child:iter_children() do
				if header_part:type() == "header_entity" then
					local name = vim.treesitter.get_node_text(header_part, bufnr)
					result.headers[name] = nil -- Initialize header name
				elseif header_part:type() == "value" then
					local value = vim.treesitter.get_node_text(header_part, bufnr):gsub("^%s*(.-)%s*$", "%1")
					-- Assign value to the last header name
					for name, _ in pairs(result.headers) do
						result.headers[name] = value
						break
					end
				end
			end
			log.debug(string.format("Found header: %s", vim.inspect(result.headers)))
		elseif child:type() == "json_body" then
			result.body = vim.treesitter.get_node_text(child, bufnr)
			log.debug("Found JSON body")
		end
	end

	log.info("Successfully parsed HTTP request")
	return result
end

local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

function M.parse_http_request(request_str)
	if not request_str or request_str == "" then
		return nil
	end

	local result = {
		method = nil,
		url = nil,
		headers = {},
		body = nil,
	}

	-- Split into request line and body
	local request_line, body = request_str:match("^([^\n]+)\n\n(.+)$")
	if not request_line then
		return nil
	end

	-- Parse request line
	local method, url = request_line:match("^(%S+)%s+(%S+)")
	if not method or not url then
		return nil
	end

	result.method = method
	result.url = url
	result.body = trim(body)

	return result
end

return M
