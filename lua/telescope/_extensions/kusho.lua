local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
	error("This plugin requires nvim-telescope/telescope.nvim")
end

-- Import the actual implementation
local kusho_telescope = require("kusho.telescope")

-- This is what telescope will load
return telescope.register_extension({
	exports = {
		kusho = kusho_telescope.find_test_suites,
	},
})
