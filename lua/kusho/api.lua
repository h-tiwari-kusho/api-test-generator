-- lua/kusho/api.luaapi
local M = {}
local config = require("kusho.config")
local parser = require("kusho.parser")
local ui = require("kusho.ui")
local utils = require("kusho.utils")
local log = require("kusho").log

---@class HttpRequest
---@field method string
---@field url string
---@field headers table<string, string>|nil
---@field body string|table|nil
---@field query_params table|nil
---@field path_params table|nil
---@field json_body table|nil

---@class TestCase
---@field request HttpRequest
---@field description string
---@field categories string[]
---@field types string[]
---@field test_suite_id number
---@field uuid string
---@field modify_key_values table

-- Constants
local STREAMING_API_ENDPOINT = "https://be.kusho.ai/vscode/generate/streaming"
-- "http://localhost:8080/vscode/generate/streaming"
-- local MACHINE_ID = "12412534"

-- HTTP Utilities
---@param request HttpRequest
---@return string
local function format_http_request(request)
	if not request then
		return ""
	end

	local parts = {}
	-- Add request line
	table.insert(parts, string.format("%s %s", request.method, request.url))

	-- Add headers
	if request.headers and not vim.tbl_isempty(request.headers) then
		for name, value in pairs(request.headers) do
			table.insert(parts, string.format("%s: %s", name, value))
		end
	end

	-- Add body
	if request.body then
		table.insert(parts, "") -- Empty line before body
		if type(request.body) == "table" then
			table.insert(parts, vim.json.encode(request.body))
		else
			table.insert(parts, request.body)
		end
	elseif request.json_body and not vim.tbl_isempty(request.json_body) then
		table.insert(parts, "")
		table.insert(parts, vim.json.encode(request.json_body))
	end

	return table.concat(parts, "\n")
end

---@param test_case TestCase
---@return string
local function format_test_case(test_case)
	if not test_case then
		log.warn("Empty test case received")
		return ""
	end

	-- Debug log the received test case
	log.trace("Formatting test case", {
		raw_test_case = vim.inspect(test_case),
	})

	local parts = {}

	-- Add test case metadata if available
	if type(test_case) == "table" then
		if test_case.description then
			table.insert(parts, string.format("### %s ###", test_case.description))
		end

		if type(test_case.categories) == "table" then
			table.insert(parts, string.format("# Categories: %s", table.concat(test_case.categories, ", ")))
		end

		if type(test_case.types) == "table" then
			table.insert(parts, string.format("# Types: %s", table.concat(test_case.types, ", ")))
		end

		if #parts > 0 then
			table.insert(parts, "") -- Empty line after metadata
		end
	end

	-- Handle the request part
	local request = test_case.request or test_case
	if type(request) == "table" then
		-- Ensure we have the minimum required fields
		if request.method and request.url then
			-- Add request line
			table.insert(parts, string.format("%s %s", request.method, request.url))

			-- Add headers if present
			if type(request.headers) == "table" and not vim.tbl_isempty(request.headers) then
				for name, value in pairs(request.headers) do
					table.insert(parts, string.format("%s: %s", name, value))
				end
			end

			-- Add empty line before body
			table.insert(parts, "")

			-- Handle body
			if request.body then
				if type(request.body) == "table" then
					table.insert(parts, vim.json.encode(request.body))
				elseif type(request.body) == "string" then
					table.insert(parts, request.body)
				end
			elseif type(request.json_body) == "table" and not vim.tbl_isempty(request.json_body) then
				table.insert(parts, vim.json.encode(request.json_body))
			end
		else
			log.warn("Missing required fields in request", {
				has_method = request.method ~= nil,
				has_url = request.url ~= nil,
			})
		end
	end

	table.insert(parts, "\n###\n")
	return table.concat(parts, "\n")
end

-- File handling
---@param path string
---@param content string
local function append_to_file(path, content)
	local file = io.open(path, "a")
	if not file then
		error(string.format("Failed to open file: %s", path))
	end
	file:write(content)
	file:flush()
	file:close()
end

---@param path string
---@param content string
local function write_to_file(path, content)
	local file = io.open(path, "w")
	if not file then
		error(string.format("Failed to open file: %s", path))
	end
	file:write(content)
	file:flush()
	file:close()
end

function M.parse_http_response_status(raw_response)
	-- If input is a string (not already split), split it into lines
	local first_line
	if type(raw_response) == "string" then
		-- Remove the leading/trailing quotes if present
		raw_response = raw_response:gsub("^'(.+)'$", "%1")
		first_line = raw_response:match("^[^\r\n]+")
	else
		-- Handle case where input might be pre-split
		first_line = raw_response[1]
	end

	-- Clean the status line by removing both \r and extra whitespace
	first_line = first_line:gsub("\r", "") -- Remove carriage returns
	first_line = first_line:match("^%s*(.-)%s*$") -- Trim whitespace

	-- Parse status code, supporting both HTTP/1.1 and HTTP/2
	local status = first_line:match("HTTP/[%d%.]+ (%d+)")
	if not status then
		log.error("Could not parse status code", { status_line = first_line })
		error("Could not parse status code from response")
	end

	return tonumber(status)
end

---@class ApiResponse
---@field status number The HTTP status code
---@field headers table<string, string> Parsed response headers
---@field body table|string The parsed response body (JSON decoded if possible)
---@field raw_body string The raw response body before parsing
---@field raw_headers string The raw headers string

---Parse HTTP headers string into a table
---@param headers_str string
---@return table<string, string>
local function parse_headers(headers_str)
	local headers = {}
	local header_lines = vim.split(headers_str, "\r?\n")
	-- Skip the first line as it's the status line
	for i = 2, #header_lines do
		local line = header_lines[i]
		if line ~= "" then
			local name, value = line:match("^([^:]+):%s*(.+)$")
			if name and value then
				-- Convert header names to lowercase for consistency
				headers[name:lower()] = value
			end
		end
	end
	return headers
end

---@param method string
---@param url string
---@param body table|string|nil
---@param headers table<string,string>|nil
---@return ApiResponse
function M.make_api_request(method, url, body, headers)
	-- Prepare headers
	local default_headers = { ["Content-Type"] = "application/json" }
	if config.options.auth_token then
		default_headers["Authorization"] = "Bearer " .. config.options.auth_token
	end
	local request_headers = vim.tbl_extend("force", default_headers, headers or {})

	-- Build curl command
	local curl_cmd = {
		"curl",
		"-s", -- silent mode
		"-i", -- include headers in output
		"-X",
		method:upper(), -- HTTP method
		"-L", -- follow redirects
		"--max-redirs",
		"5", -- maximum number of redirects
	}

	-- Add headers
	for name, value in pairs(request_headers) do
		table.insert(curl_cmd, "-H")
		table.insert(curl_cmd, string.format("%s: %s", name, value))
	end

	-- Add body if present
	if body then
		table.insert(curl_cmd, "-d")
		if type(body) == "table" then
			table.insert(curl_cmd, vim.json.encode(body))
		else
			table.insert(curl_cmd, tostring(body))
		end
	end

	-- Add URL (must be last)
	table.insert(curl_cmd, url)

	-- Log the request
	log.debug("Making API request", {
		method = method,
		url = url,
		curl_cmd = table.concat(curl_cmd, " "),
	})

	-- Execute curl command
	local output = vim.fn.system(curl_cmd)
	log.debug("OUTPUT RESULT:- ", vim.inspect(output))

	if vim.v.shell_error ~= 0 then
		log.error("API request failed", {
			error = output,
			curl_cmd = table.concat(curl_cmd, " "),
		})
		error(string.format("API request failed: %s", output))
	end

	-- Parse response
	local headers_body = vim.split(output, "\r\n\r\n")
	if #headers_body < 2 then
		headers_body = vim.split(output, "\n\n") -- try with simple newlines
	end
	if #headers_body < 2 then
		log.error("Invalid response format", { output = output })
		error("Invalid response format: couldn't separate headers and body")
	end

	-- Parse status and headers
	local status = M.parse_http_response_status(output)
	local headers_parsed = parse_headers(headers_body[1])
	local raw_body = headers_body[2]

	-- Log response details
	log.debug("Received response", {
		status = status,
		body_length = #raw_body,
	})

	-- Check status code
	if status >= 400 then
		log.error("API request failed", {
			status = status,
			body = raw_body,
		})
		error(string.format("API request failed with status %d: %s", status, raw_body))
	end

	-- Try to parse JSON response
	local parsed_body = raw_body
	local success, result = pcall(vim.json.decode, raw_body)
	if success then
		parsed_body = result
	end

	-- Return complete response object
	return {
		status = status,
		headers = headers_parsed,
		body = parsed_body,
		raw_body = raw_body,
		raw_headers = headers_body[1],
	}
end

function M.process_api_request()
	local api_request = parser.get_api_request_at_cursor()
	if not api_request then
		vim.notify("No API request found at cursor position", vim.log.levels.ERROR)
		return
	end

	local request_hash = utils.hash_request(api_request)
	local output_dir = string.format("%s/%s", config.options.api.save_directory, request_hash)
	local output_file = output_dir .. "/test_cases.http"
	local response_file = output_dir .. "/response.tmp"

	log.info("Test Case File", { output_file = output_file })

	-- Ensure directory exists and write initial content
	utils.ensure_directory(output_dir)
	write_to_file(
		output_file,
		"### Original Request ###\n" .. format_http_request(api_request) .. "\n\n### Generated Test Cases ###\n"
	)

	-- Create and manage status window
	local status_window = ui.create_status_window()
	status_window.update("Generating Test Cases. Please Do not close this window or close vim.")
	status_window.update("### Original Request ###")
	status_window.update(vim.inspect(format_http_request(api_request)))
	status_window.update("### Generating Test Cases ###")

	local function update_status(message)
		status_window.update(message)
		log.info("Message:-", { message = message })

		if message:match("completed") or message:match("Error:") then
			vim.defer_fn(function()
				-- Close status window
				status_window.close()

				-- Split window and open the file
				vim.cmd("vsplit " .. output_file)
			end, 3000)
		end

		-- if message:match("completed") or message:match("Error:") then
		-- 	vim.defer_fn(function()
		-- 		status_window.close()
		-- 	end, 3000)
		-- end
	end

	-- Setup curl request
	local json_payload = vim.json.encode({
		machine_id = require("kusho.machine_id").get_machine_id(),
		api_info = api_request,
		test_suite_name = api_request.url,
	})

	-- Start curl process writing to temp file
	local curl_cmd = string.format(
		"curl --silent --show-error --fail -N -X POST %s -H 'Content-Type: application/json' -d '%s' > %s",
		STREAMING_API_ENDPOINT,
		json_payload:gsub("'", "'\\''"), -- Escape single quotes for shell
		response_file
	)

	local test_case_count = 0
	local curl_handle = io.popen(curl_cmd, "w")
	local last_size = 0
	local file_handle

	-- Check for new data every 100ms
	local timer = vim.loop.new_timer()
	timer:start(
		0,
		100,
		vim.schedule_wrap(function()
			-- Open file if not already open
			if not file_handle then
				file_handle = io.open(response_file, "r")
				if not file_handle then
					return
				end
			end

			-- Seek to where we last read
			file_handle:seek("set", last_size)

			-- Read new chunks
			local chunk = file_handle:read("*line")
			while chunk do
				log.debug("Received line", { line = chunk })

				if chunk == "event:done" then
					log.info("Streaming completed", { total_cases = test_case_count })
					update_status(string.format("Generation completed. %d test cases generated.", test_case_count))
					timer:stop()
					file_handle:close()
					os.remove(response_file)
					return
				end

				if chunk:match("event:limit_error") then
					log.warn("Test suite limit reached")
					update_status(
						"Error: You have reached the limit of 5 test suites. Please use the KushoAI web app for more."
					)
					vim.notify(
						"Error: You have reached the limit of 5 test suites. Please use the KushoAI web app for more."
					)
					timer:stop()
					file_handle:close()
					os.remove(response_file)
					return
				end

				if chunk:match("^data:") then
					local json_str = chunk:gsub("^data:", "")

					local success, test_case = pcall(function()
						local decoded = vim.json.decode(json_str)
						if type(decoded) ~= "table" then
							error("Decoded JSON is not a table")
						end
						return decoded
					end)

					if success then
						test_case_count = test_case_count + 1
						log.debug("Successfully parsed test case", {
							number = test_case_count,
							test_case_type = type(test_case),
							has_request = test_case.request ~= nil,
						})

						local formatted_case = format_test_case(test_case)
						if formatted_case ~= "" then
							local append_success, err = pcall(append_to_file, output_file, formatted_case)
							if append_success then
								update_status(string.format("Generated test case %d", test_case_count))
							else
								log.error("Failed to write test case to file", { error = err })
								update_status(string.format("Error writing test case %d to file", test_case_count))
							end
						else
							log.warn("Empty formatted test case", {
								test_case_number = test_case_count,
							})
						end
					else
						log.error("Failed to parse test case JSON", {
							json = json_str,
							error = test_case,
						})
						update_status(string.format("Error: Failed to parse test case %d", test_case_count + 1))
					end
				end

				-- Update last read position
				last_size = file_handle:seek()
				chunk = file_handle:read("*line")
			end

			-- Check if curl process has ended
			local status = nil
			if curl_handle then
				status = curl_handle:close()
			end
			if not status then
				log.error("Curl process failed")
				update_status("Error: Streaming request failed")
				timer:stop()
				if file_handle then
					file_handle:close()
				end
				os.remove(response_file)
				return
			end
		end)
	)
end

function M.run_current_request()
	-- Get request at cursor
	local request = parser.get_api_request_at_cursor()
	if not request then
		vim.notify("No API request found at cursor position", vim.log.levels.ERROR)
		return
	end

	-- Prepare headers
	local headers = request.headers or {}
	if request.json_body then
		headers["Content-Type"] = "application/json"
	end

	-- Prepare body
	local body
	if request.json_body then
		body = vim.json.encode(request.json_body)
	elseif request.body then
		if type(request.body) == "table" then
			body = vim.json.encode(request.body)
		else
			body = request.body
		end
	end

	-- Log request details
	log.debug("Executing request", {
		method = request.method,
		url = request.url,
		headers = headers,
		body = body,
		raw = vim.inspect(request),
	})

	-- Execute request
	local response = M.make_api_request(request.method, request.url, request.body, request.headers)
	-- {
	-- 	url = request.url,
	-- 	body = body,
	-- 	headers = headers,
	-- 	raw = true, -- Get raw response for headers
	-- })

	-- Display response in new buffer
	log.debug("FINAL RESPONSE", { response = response })

	local output_buffer = ui.display_response(response)

	return output_buffer
end

return M
