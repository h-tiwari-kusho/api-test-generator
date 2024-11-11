local utils = require("kusho.utils")

local M = {}

M.config = {
	test_suites_dir = vim.fn.expand("~/.local/share/nvim/test_suites/"),
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	utils.ensure_dir_exists(M.config.test_suites_dir)
end

function M.create_test_suite_file(opts)
	opts = opts or {}
	local user_id = opts.user_id or utils.generate_uniquer_id()

	-- Maybe we do not need this. We should create on test suite for each api
	local timestamp = utils.get_timestamp()
	local description = opts.description or "api_request"
end
