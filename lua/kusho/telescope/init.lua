local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("This plugin requires nvim-telescope/telescope.nvim")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local utils = require("kusho.utils")
local config = require("kusho.config")

local M = {}

-- Format the request for display
local function format_request_for_display(request)
	-- Split the request into lines and get the first line
	local first_line = request:match("[^\n]+")
	-- If it's too long, truncate it
	if #first_line > 50 then
		return first_line:sub(1, 47) .. "..."
	end
	return first_line
end

-- Create a custom previewer
local test_case_previewer = previewers.new_buffer_previewer({
	title = "Test Case Preview",
	define_preview = function(self, entry)
		-- Get the full request content
		local content = entry.full_request

		-- Set the buffer content
		vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(content, "\n"))

		-- Set the filetype to http for syntax highlighting
		vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "http")
	end,
})

function M.find_test_suites(opts)
	opts = opts or {}

	local all_requests_table = utils.get_all_original_requests()

	local results = {}
	for suite_id, request in pairs(all_requests_table) do
		table.insert(results, {
			suite_id = suite_id,
			display = format_request_for_display(request),
			full_request = request,
			path = string.format("%s/%s/test_cases.http", config.options.api.save_directory, suite_id),
		})
	end

	pickers
		.new(opts, {
			prompt_title = "Kusho Test Cases",
			finder = finders.new_table({
				results = results,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.suite_id .. ": " .. entry.display,
						ordinal = entry.suite_id .. " " .. entry.display,
						full_request = entry.full_request,
						path = entry.path,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = test_case_previewer,
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					vim.cmd("edit " .. selection.path)

					local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
					for i, line in ipairs(lines) do
						if line:match("### Original Request ###") then
							vim.api.nvim_win_set_cursor(0, { i + 1, 0 })
							break
						end
					end
				end)

				-- Use mapping from config
				local copy_mapping = require("kusho").config.telescope.mappings.copy_to_clipboard
				vim.keymap.set("i", copy_mapping, function()
					local selection = action_state.get_selected_entry()
					vim.fn.setreg("+", selection.full_request)
					print("Copied request to clipboard!")
				end, { buffer = prompt_bufnr })

				return true
			end,
		})
		:find()
end

-- Register the extension
return telescope.register_extension({
	exports = {
		test_cases = M.find_test_suites,
	},
})

-- return M
