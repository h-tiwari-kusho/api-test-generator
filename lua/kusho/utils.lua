local M = {}

-- Get the shared log object
local log = require("kusho").log
local ui = require("kusho.ui")
local config = require("kusho.config")
-- local api = require("kusho.api")
local parser = require("kusho.parser")

-- local json = require("cjson")

function M.ensure_directory(path)
	vim.fn.mkdir(path, "p")
end

function M.save_json(data, filepath)
	local file = io.open(filepath, "w")
	if file then
		file:write(vim.json.encode(data))
		file:close()
		return true
	end
	return false
end

function M.generate_timestamp()
	return os.date("%Y%m%d_%H%M%S")
end

function M.parse_current_request()
	log.info("Starting parse_current_request")
	local request = require("kusho.parser").get_api_request_at_cursor()

	if request then
		return ui.display_request(request)
	else
		log.warn("No HTTP request found at cursor position")
		vim.notify("No HTTP request found at cursor position", vim.log.levels.WARN)
	end
end

-- Add utility functions to view logs
function M.show_logs()
	local log_file = string.format("%s/kusho.log", vim.fn.stdpath("cache"))
	vim.cmd(string.format("split %s", log_file))
end

-- Function to clear logs
function M.clear_logs()
	local log_file = string.format("%s/kusho.log", vim.fn.stdpath("cache"))
	local f = io.open(log_file, "w")
	if f then
		f:close()
		vim.notify("Kusho logs cleared", vim.log.levels.INFO)
		log.info("Logs cleared")
	else
		vim.notify("Failed to clear logs", vim.log.levels.ERROR)
		log.error("Failed to clear logs")
	end
end

function M.generate_unique_id()
	-- Generate a UUID-like string
	local random = math.random
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

	return string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
		return string.format("%x", v)
	end)
end

function M.get_timestamp()
	return os.date("%Y%m%d_%H%M%S")
end

function M.ensure_directory_exists(path)
	local cmd = string.format('mkdir -p "%s"', path)
	vim.fn.system(cmd)
end

-- Function to open the generated test cases
function M.open_test_cases(filepath)
	vim.cmd("edit " .. filepath)

	-- Set filetype for syntax highlighting
	vim.cmd("set filetype=http")
end

function M.open_latest_test_cases()
	local pattern = config.options.save_directory .. "/*"
	local dirs = vim.fn.glob(pattern, false, true)
	table.sort(dirs) -- Latest will be last due to timestamp format

	if #dirs > 0 then
		local latest = dirs[#dirs] .. "/test_cases.http"
		if vim.fn.filereadable(latest) == 1 then
			M.open_test_cases(latest)
		else
			vim.notify("No test cases file found", vim.log.levels.ERROR)
		end
	else
		vim.notify("No test cases have been generated yet", vim.log.levels.ERROR)
	end
end

-- lua/kusho/utils.lua
function M.hash_request(request)
	if not request or not request.method or not request.url then
		return "unknown"
	end

	-- Create a simple hash using string manipulation
	local str = request.method .. request.url
	local hash = 0

	for i = 1, #str do
		hash = (hash * 31 + string.byte(str, i)) % 0x100000000
	end

	-- Convert to hex string and take first 8 characters
	return string.format("%08x", hash)
end

-- Utility function to get all test suite directories
local function get_test_directories(root_path)
	local test_dirs = {}
	local scan = require("plenary.scandir")

	scan.scan_dir(root_path, {
		hidden = false,
		add_dirs = false,
		respect_gitignore = true,
		depth = 2, -- We only need to go 2 levels deep
		search_pattern = "test_cases%.http$",
		on_insert = function(entry)
			table.insert(test_dirs, entry)
		end,
	})

	return test_dirs
end

-- Function to extract original request from a file
local function extract_original_request(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	-- Find the section after ### Original Request ###
	local pattern = "### Original Request ###\n(.-)###"
	local original_request = content:match(pattern)

	if original_request then
		-- Trim whitespace
		return original_request:gsub("^%s*(.-)%s*$", "%1")
	end

	return nil
end

-- Function to get all original requests from test suites
function M.get_all_original_requests()
	local results = {}

	local test_files = get_test_directories(config.options.api.save_directory)

	for _, file_path in ipairs(test_files) do
		local request = extract_original_request(file_path)
		if request then
			-- Use the parent directory name as the key
			local parent_dir = vim.fn.fnamemodify(file_path, ":h:t")
			results[parent_dir] = request
		end
	end

	log.debug("ALLDIRS", vim.inspect(results))
	return results
end

return M
