local M = {}

local config = require("kusho.config")

-- Initialize logger with default configuration
local log = require("plenary.log").new({
	plugin = "kusho",
	level = "debug",
	use_console = "async",
	use_file = true,
	-- This will create the log file in the neovim cache directory
	filename = string.format("%s/kusho.log", vim.fn.stdpath("cache")),
})

function M.setup(opts)
	config.setup(opts)
	local machine_id = require("kusho.machine_id").get_machine_id()
	log.debug("Machine ID: " .. machine_id)

	-- Update log configuration
	-- if M.config.log then
	-- 	log.level = M.config.log.level or "debug"
	-- 	log.use_console = M.config.log.use_console or "async"
	-- 	log.use_file = M.config.log.use_file or true
	-- end

	-- Check dependencies
	require("kusho.dependencies").check()

	-- Setup commands
	local commands = require("kusho.commands")
	commands.setup()

	require("kusho.utils").ensure_directory(config.options.api.save_directory)

	require("telescope").load_extension("kusho")

	log.info("Kusho plugin initialized")
end

-- Export the log object so it can be used in other modules
M.log = log

function M.kusho()
	log.debug("Kusho command executed")
	require("kusho.utils").parse_current_request()
end

-- function M.create_test_suite()
-- 	log.debug("Creating Test Suite")
-- 	require("kusho.utils").process_api_request()
-- end

-- Function to get current configuration
function M.get_config()
	return M.config
end

return M
