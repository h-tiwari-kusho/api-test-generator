local M = {}
local utils = require("kusho.utils")
local api = require("kusho.api")

function M.setup()
	-- Main command for parsing HTTP requests
	vim.api.nvim_create_user_command("ParseHttpRequest", function()
		utils.parse_current_request()
	end, {
		desc = "Parse HTTP request at cursor position",
	})

	-- Command to view logs
	vim.api.nvim_create_user_command("KushoShowLogs", function()
		utils.show_logs()
	end, {
		desc = "Show Kusho plugin logs",
	})

	-- Command to clear logs
	vim.api.nvim_create_user_command("KushoClearLogs", function()
		utils.clear_logs()
	end, {
		desc = "Clear Kusho plugin logs",
	})

	-- Add more custom commands
	vim.api.nvim_create_user_command("KushoVersion", function()
		vim.notify("Kusho v1.0.0", vim.log.levels.INFO)
	end, {
		desc = "Show Kusho version",
	})

	vim.api.nvim_create_user_command("KushoCreateTests", function()
		api.process_api_request()
	end, {
		desc = "Show Kusho version",
	})

	vim.api.nvim_create_user_command("KushoOpenLatest", function()
		require("kusho.utils").open_latest_test_cases()
	end, {})
end

return M
