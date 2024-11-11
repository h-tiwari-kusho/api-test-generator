local M = {}

function M.check()
	-- Check for plenary.nvim
	local has_plenary, _ = pcall(require, "plenary")
	if not has_plenary then
		error("This plugin requires nvim-lua/plenary.nvim. Please install it first.")
	end
end

return M
