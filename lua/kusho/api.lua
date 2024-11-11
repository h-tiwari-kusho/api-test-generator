-- lua/kusho/api.lua
local M = {}
local curl = require("plenary.curl")
local config = require("kusho.config")
local parser = require("kusho.parser")
local ui = require("kusho.ui")
local utils = require("kusho.utils")
local Job = require("plenary.job")
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
local STREAMING_API_ENDPOINT = "http://localhost:8080/vscode/generate/streaming"
local MACHINE_ID = "12412534"

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

-- API Request handling
local function make_api_request(method, url, body, headers)
	local default_headers = { ["Content-Type"] = "application/json" }
	if config.options.auth_token then
		default_headers["Authorization"] = "Bearer " .. config.options.auth_token
	end

	local request_headers = vim.tbl_extend("force", default_headers, headers or {})
	log.debug("Making API request", { method = method, url = url })

	local response = curl[string.lower(method)]({
		url = url,
		body = body and vim.json.encode(body) or nil,
		headers = request_headers,
	})

	if response.status >= 400 then
		log.error("API request failed", { status = response.status, body = response.body })
		error(string.format("API request failed: %s", response.body))
	end

	return vim.json.decode(response.body)
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
		machine_id = MACHINE_ID,
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
			local status = curl_handle:close()
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

-- API Functions
function M.submit_api_request(api_data)
	return make_api_request("POST", "/api/submit", { api_request = api_data })
end

function M.create_test_suite(token)
	return make_api_request("POST", "/api/test-suites", { token = token })
end

function M.fetch_test_cases(test_suite_id)
	return make_api_request("GET", "/api/test-suites/" .. test_suite_id)
end

return M
