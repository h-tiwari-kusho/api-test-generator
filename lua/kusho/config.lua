local M = {}

local default_config = {
	log = {
		level = "debug",
		use_console = "async",
		use_file = true,
	},
	view = {
		-- Window position
		position = "right", -- 'left', 'right', 'top', 'bottom'
		-- Window size
		width = 80, -- for vertical splits
		height = 20, -- for horizontal splits
		-- Window options
		border = true,
		wrap = true,
		number = true,
	},
	commands = {
		parse_request = "ParseHttpRequest",
		show_logs = "KushoShowLogs",
		clear_logs = "KushoClearLogs",
		version = "KushoVersion",
	},
	api = {
		-- TODO: Change it
		base_url = "https://your-api-endpoint.com",
		auth_token = nil,
		polling_interval = 2000,
		max_retries = 30,
		save_directory = vim.fn.stdpath("data") .. "/kusho/test_suites",
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", default_config, opts or {})
end

return M
